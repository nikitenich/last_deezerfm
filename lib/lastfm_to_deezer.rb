module LastDeezerFm
  class Importer
    require 'launchy'

    def initialize(lastfm:, deezer:, lastfm_user: nil)
      raise 'Argument should be a LastFm instance!' unless lastfm.is_a? Lastfm
      raise 'Argument should be a Deezer instance!' unless deezer.is_a? LastDeezerFm::Deezer
      raise 'Lastfm username cannot be nil!' if lastfm_user.nil?

      @lastfm = lastfm
      @deezer = deezer
      @lastfm_user = lastfm_user
      @playlist_prefix = 'LastFM-loved-'.freeze
      @playlists = playlists
      @timestamp = Time.now.strftime('%d-%m-%Y_%T')
      @puts_args = {filename: 'import_log', timestamp: @timestamp}
    end

    def lastfm_loved
      @lastm_loved_tracks = get_lastfm_loved_tracks

      create_lastfm_playlist if @playlists.empty? # create deezer playlist if not yet

      # gets last playlist id created by this script
      playlist_with_last_track = if @playlists.last[:tracks_count].zero? && @playlists.count > 1
                                   @playlists[-2][:id]
                                 else
                                   @playlists.last[:id]
                                 end

      start_index = last_added_to_playlist_track(playlist_with_last_track)

      return if start_index == @lastm_loved_tracks.count - 1

      (start_index..@lastm_loved_tracks.count - 1).each do |i|
        lfm_track = @lastm_loved_tracks[i]
        lfm_track_name = "#{lfm_track[:artist]} - #{lfm_track[:title]}"
        deezer_tracks_search_result = @deezer.find_track(lfm_track_name)
        puts("#{i + 1}) #{lfm_track_name}", @puts_args)
        selected_track = choose_track(deezer_tracks_search_result, lfm_track[:artist], lfm_track[:title])
        if selected_track.nil?
          FileHelper.save_file(lfm_track_name, filename: 'not_found', extension: :txt, mode: 'a')
        else
          puts('Selected result:', @puts_args)
          puts(selected_track, @puts_args)

          lastfm_playlist_action do |playlist|
            # adding track to playlist
            @deezer.add_track_to_playlist(playlist_id: playlist, track_id: selected_track[:id]) do |success|
              if success
                puts("Track #{selected_track[:artist]} - #{selected_track[:title]} added to playlist", @puts_args)
              end
            end
            # adding track to favourites
            unless @deezer.favourite_track?(selected_track[:id])
              @deezer.like_track(selected_track[:id]) do |success|
                if success
                  @deezer.favourite_tracks_ids.push(selected_track[:id])
                  puts("Track #{selected_track[:artist]} - #{selected_track[:title]} added to favourites.", @puts_args)
                end
              end
            end
          end
        end
      end
    end

    private

    # Loads loved tracks from Last.fm to array of hashes
    def get_lastfm_loved_tracks
      if FileHelper.file_exists?
        loved_tracks_count = @lastfm.user.loved_count(@lastfm_user)
        file = FileHelper.read_file.map { |h| h.transform_keys(&:to_sym) }
        if file.count >= loved_tracks_count
          puts('Seems there is no new loved Last.fm tracks. Loaded from file.', @puts_args)
        else
          new_loved_tracks_count = loved_tracks_count - file.count
          puts "Found #{new_loved_tracks_count} new Last.fm loved tracks. Let's update saved file."
          pages_to_download = new_loved_tracks_count / LASTFM_PAGE_SIZE + (new_loved_tracks_count % LASTFM_PAGE_SIZE > 0 ? 1 : 0)
          updated_pages = []
          (1..pages_to_download).each do |page|
            updated_pages << @lastfm.user.get_loved_tracks(user: @lastfm_user, page: page)
          end
          updated_pages.reverse!.flatten!.map! do |e|
            Hash.new.tap do |h|
              h[:title] = e['name']
              h[:artist] = e['artist']['name']
            end
          end
          updated_pages.dup.shift(new_loved_tracks_count).each do |new_track|
            file << new_track
          end
          FileHelper.save_file(file)
        end
        file
      else # download from last.fm if file not exists
        loaded_loved_tracks = @lastfm.user.get_all_loved_tracks(user: @lastfm_user).reverse.map do |e|
          Hash.new.tap do |h|
            h[:title] = e['name']
            h[:artist] = e['artist']['name']
          end
        end
        FileHelper.save_file(loaded_loved_tracks)
        loaded_loved_tracks
      end
    end

    # Creates new playlist and returns his id
    def create_lastfm_playlist
      new_playlist_id = @deezer.create_playlist(@playlist_prefix + (@playlists.count + 1).to_s) do |success|
        puts("Playlist \"#{name}\" was successfully created.", @puts_args) if success
      end['id']
      playlists.detect { |e| e[:id] == new_playlist_id }[:id]
    end

    def playlists
      results = @deezer.playlists.select { |e| e['title'].include?(@playlist_prefix) }
      @playlists = results.map do |playlist|
        Hash.new.tap do |h|
          h[:id] = playlist['id']
          h[:title] = playlist['title']
          h[:tracks_count] = playlist['nb_tracks'].to_i
        end
      end
    end

    # chooses playlist for actions
    # returns playlist id
    def choose_lastfm_playlist
      last_created_playlist = playlists.last
      last_created_playlist[:tracks_count] >= DEEZER_MAX_PLAYLIST_TRACKS ? create_lastfm_playlist : last_created_playlist[:id]
    end

    def lastfm_playlist_action
      playlist = choose_lastfm_playlist
      yield playlist
    end

    # Chooses track from search results
    def choose_track(deezer_response, artist, title)
      case deezer_response.count
      when 1
        searched_songs_mapping(deezer_response).first
      when 0
        puts("Track #{artist} - #{title} not found in Deezer.", @puts_args)
        nil
      else
        searched_songs_mapping(deezer_response).select do |track|
          TextHelper.names_similar?(track[:artist].downcase, artist.downcase) &&
              TextHelper.names_similar?(track[:title].downcase, title.downcase)
        end.first
      end
    end

    # Returns index of last added deezer playlist track in
    # lastfm loved tracks
    def last_added_to_playlist_track(playlist_id)
      last_playlist_track = searched_songs_mapping(@deezer.playlist_tracks(playlist_id, all: true).last)
      if last_playlist_track.nil?
        0
      else
        last_playlist_track_lastfm = @lastm_loved_tracks.detect do |loved_track|
          TextHelper.names_similar?(loved_track[:title].downcase, last_playlist_track[:title].downcase) &&
              TextHelper.names_similar?(loved_track[:artist].downcase, last_playlist_track[:artist].downcase)
        end
        @lastm_loved_tracks.index(last_playlist_track_lastfm)
      end
    end

    def searched_songs_mapping(find_track_response)
      case find_track_response
      when Array
        find_track_response.map do |track|
          Hash.new.tap do |h|
            h[:id] = track['id']
            h[:title] = track['title']
            h[:artist] = track['artist']['name']
            h[:album] = track['album']['title']
          end
        end
      when Hash
        Hash.new.tap do |h|
          h[:id] = find_track_response['id']
          h[:title] = find_track_response['title']
          h[:artist] = find_track_response['artist']['name']
          h[:album] = find_track_response['album']['title']
        end
      end

    end

  end

end
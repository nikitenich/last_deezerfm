module LastDeezerFm
  class Importer
    require 'launchy'
    require 'securerandom'

    def initialize(lastfm:, deezer:, lastfm_user: nil)
      raise 'Argument should be a LastFm instance!' unless lastfm.is_a? Lastfm
      raise 'Argument should be a Deezer instance!' unless deezer.is_a? LastDeezerFm::Deezer
      raise 'Lastfm username cannot be nil!' if lastfm_user.nil?

      @lastfm = lastfm
      @deezer = deezer
      @lastfm_user = lastfm_user
      @playlist_prefix = 'LastFM-loved-'.freeze
      @playlists = playlists
      @uid = SecureRandom.hex(5)
    end

    # Импортирует любимые треки из lastfm
    def lastfm_loved
      # Получаем любимые треки с lastfm либо из файла, если изменений не было
      loved_tracks = get_lastfm_loved_tracks

      create_lastfm_playlist if @playlists.empty? # создаём плейлист, если нет ни одного

      # получаем последнюю песню в плейлисте в deezer,
      # чтобы не начинать импорт с самого начала
      playlist_with_last_track = if @playlists.last[:tracks_count].zero? && @playlists.count > 1
                                   @playlists[-2][:id]
                                 else
                                   @playlists.last[:id]
                                 end
      last_playlist_track = searched_songs_mapping(@deezer.playlist_tracks(playlist_with_last_track, all: true).last)

      start_index = if last_playlist_track.nil?
                      0
                    else
                      # получаем этот последний трек из плейлиста уже из любимых на ласте
                      last_playlist_track_lastfm = loved_tracks.detect do |loved_track|
                        TextHelper.names_similar?(loved_track[:title].downcase, last_playlist_track[:title].downcase) &&
                            TextHelper.names_similar?(loved_track[:artist].downcase, last_playlist_track[:artist].downcase)
                      end
                      loved_tracks.index(last_playlist_track_lastfm)
                    end

      return if start_index == loved_tracks.count - 1

      (start_index..loved_tracks.count - 1).each do |i|
        puts i.to_s.blue
        track = loved_tracks[i]
        lastfm_name = "#{track[:artist]} - #{track[:title]}"
        deezer_tracks_search_result = @deezer.find_track(lastfm_name)
        FileHelper.lputs(lastfm_name, @uid)
        selected_track = choose_track(deezer_tracks_search_result, track[:artist], track[:title])
        FileHelper.lputs('Selected result:', @uid)
        FileHelper.lputs(selected_track, @uid)
        if selected_track.nil?
          FileHelper.save_file(lastfm_name, filename: 'not_found', extension: :txt, mode: 'a')
        else
          lastfm_playlist_action do |playlist|
            # добавляем трек в плейлист
            @deezer.add_track_to_playlist(playlist_id: playlist, track_id: selected_track[:id]) do |success|
              if success
                FileHelper.lputs("Track #{selected_track[:artist]} - #{selected_track[:title]} added to playlist", @uid)
              end
            end
            # и лайкаем его
            @deezer.like_track(selected_track[:id]) do |success|
              if success
                FileHelper.lputs("Track #{selected_track[:artist]} - #{selected_track[:title]} added to favourites.", @uid)
              end
            end
          end
        end
      end
    end

    private

    # Загружает любимые треки с ласта в массив из хэшей
    def get_lastfm_loved_tracks
      if FileHelper.file_exists? # проверяем есть ли файл
        lastfm_loved_tracks_count = @lastfm.user.loved_count(@lastfm_user)
        file = FileHelper.read_file.map { |h| h.transform_keys(&:to_sym) }
        if file.count >= lastfm_loved_tracks_count
          puts 'Seems there is no new loved Last.fm tracks. Loaded from file.'
          file
        else
          new_loved_tracks_count = lastfm_loved_tracks_count - file.count
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
          file
        end
      else # если файла нет, то нужно бы заново вообще всё загрузить
        #старые треки будут самые первые, для удобного импорта
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

    # Создаёт новый плейлист и возвращает его id
    def create_lastfm_playlist
      new_playlist_id = @deezer.create_playlist(@playlist_prefix + (@playlists.count + 1).to_s)['id']
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

    # Выбирает плейлист. Если количество треков в последнем плейлисте < константы, то берём его,
    # иначе создаём новый
    # Возвращает id плейлиста
    def choose_lastfm_playlist
      last_created_playlist = playlists.last
      last_created_playlist[:tracks_count] >= DEEZER_MAX_PLAYLIST_TRACKS ? create_lastfm_playlist : last_created_playlist[:id]
    end

    def lastfm_playlist_action
      playlist = choose_lastfm_playlist
      yield playlist
    end

    # Выбираем наиболее приемлимый вариант трека из результатов поиска дизера
    def choose_track(deezer_response, artist, title)
      case deezer_response.count
      when 1
        searched_songs_mapping(deezer_response).first
      when 0
        puts "Track #{artist} - #{title} not found.".red
        nil
      else
        searched_songs_mapping(deezer_response).select do |track|
          TextHelper.names_similar?(track[:artist].downcase, artist.downcase) &&
              TextHelper.names_similar?(track[:title].downcase, title.downcase)
        end.first
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
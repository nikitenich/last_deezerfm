module LastDeezerFm
  class Deezer

    def initialize(api_key, secret_key)
      @api_key = api_key
      @secret_key = secret_key
      auth
      @favourite_tracks_ids = load_favourite_tracks
    end

    # returns current user's playlists
    def playlists(all = false, next_url: nil)
      uri = next_url.nil? ? 'https://api.deezer.com/user/me/playlists' : next_url
      headers = {params: {access_token: @access_token}}
      if all
        iterator_wrapper(__method__, next_url: uri)
      else
        response = RestWrapper.perform_request(uri, :get, headers)
        next_url.nil? ? response['data'] : response
      end
    end

    # returns 'true' if track was successfully added to playlist
    def add_track_to_playlist(playlist_id:, track_id:, &block)
      uri = "https://api.deezer.com/playlist/#{playlist_id}/tracks"
      headers = {params: {access_token: @access_token, songs: track_id}}
      RestWrapper.perform_request(uri, :post, headers, &block)
    end

    def delete_track_from_playlist(playlist_id:, track_id:, &block)
      uri = "https://api.deezer.com/playlist/#{playlist_id}/tracks"
      headers = {params: {access_token: @access_token, songs: track_id}}
      RestWrapper.perform_request(uri, :delete, headers, &block)
    end

    # returns array of track hashes
    def playlist_tracks(playlist_id, next_url: nil, all: false, page: nil)
      uri = next_url.nil? ? "https://api.deezer.com/playlist/#{playlist_id}/tracks" : next_url
      headers = {params: {access_token: @access_token}}
      headers.fetch(:params).merge!(index: (page - 1) * DEEZER_PAGE_SIZE) unless page.nil?
      if all
        iterator_wrapper(__method__, playlist_id, next_url: uri)
      else
        response = RestWrapper.perform_request(uri, :get, headers)
        next_url.nil? ? response['data'] : response
      end
    end

    def playlist_tracks_count(playlist_id)
      uri = "https://api.deezer.com/playlist/#{playlist_id}/tracks"
      headers = {params: {access_token: @access_token}}
      RestWrapper.perform_request(uri, :get, headers)['total']
    end

    # returns id of created playlist
    def create_playlist(name)
      uri = 'https://api.deezer.com/user/me/playlists'
      headers = {params: {access_token: @access_token, title: name}}
      RestWrapper.perform_request(uri, :post, headers)
    end

    # returns songs from deezer search
    def find_track(track_name, next_url: nil, all: false)
      uri = next_url.nil? ? 'https://api.deezer.com/search/track' : next_url
      headers = {params: {access_token: @access_token, q: track_name, strict: 'on'}}
      if all
        iterator_wrapper(__method__, track_name, next_url: uri)
      else
        response = RestWrapper.perform_request(uri, :get, headers)
        next_url.nil? ? response['data'] : response
      end
    end

    def like_track(track_id, &block)
      uri = 'https://api.deezer.com/user/me/tracks'
      headers = {params: {track_id: track_id, access_token: @access_token}}
      RestWrapper.perform_request(uri, :post, headers, &block)
    end

    def favourite_track?(track_id)
      @favourite_tracks_ids.include?(track_id)
    end

    def favourite_tracks_ids
      @favourite_tracks_ids
    end

    private

    def auth
      unless auth_valid?
        puts 'Authorization...'
        permissions = %w[basic_access manage_library delete_library]
        uri = "https://connect.deezer.com/oauth/auth.php?app_id=#{@api_key}&redirect_uri=#{DEEZER_REDIRECT_URI}&perms=#{permissions.join(',')}"
        Launchy.open(uri)
        print 'Enter code from url: '
        @code = STDIN.gets.chomp
        access_token_uri = 'https://connect.deezer.com/oauth/access_token.php'
        headers = {params: {app_id: @api_key, secret: @secret_key, code: @code}}
        response = RestWrapper.perform_request(access_token_uri, :get, headers)
        begin
          response = Hash[*response.split('&').collect { |i| i.split('=') }.flatten]
        rescue StandardError
          raise "Received incorrect response: \"#{response}\"."
        end
        @access_token = response.fetch('access_token')
        FileHelper.save_file(@access_token, extension: :txt)
      end
    end

    # проверяем, доступны ли какие-то действия по старому токену
    def auth_valid?
      if FileHelper.file_exists?(filename: 'auth', extension: :txt)
        possible_token = FileHelper.read_file(filename: 'auth', extension: :txt)
        uri = 'https://api.deezer.com/user/me/playlists'
        headers = {params: {access_token: possible_token}}
        RestWrapper.perform_request(uri, :get, headers) do |success|
          if success
            @access_token = possible_token
            puts 'Saved access token is still valid, so use it.'
          end
          return success
        end
      else
        false
      end
    end

    def iterator_wrapper(method_name, *arg)
      responses = []
      response = send(method_name, *arg)
      responses << response
      while response.key?('next')
        response = send(method_name, *arg[0], next_url: response['next'])
        responses << response
      end
      responses.map { |e| e['data'] }.flatten
    end

    def load_favourite_tracks
      filename = 'deezer_favourites'
      favourite_playlist_id = playlists.detect { |e| e['is_loved_track'] }['id']
      if FileHelper.file_exists?(filename: filename, extension: :json)
        tracks_count = playlist_tracks_count(favourite_playlist_id)
        file = FileHelper.read_file(filename: filename, extension: :json)
        if file.count >= tracks_count
          puts('Seems there is no new favourite Deezer tracks. Loaded from file.')
        else
          new_tracks_count = tracks_count - file.count
          puts "Found #{new_tracks_count} new Deezer favourite tracks. Let's update saved file."
          pages_to_download = new_tracks_count / DEEZER_PAGE_SIZE + (new_tracks_count % DEEZER_PAGE_SIZE > 0 ? 1 : 0)

          start_page = tracks_count / DEEZER_PAGE_SIZE
          updated_pages = []

          start_page.downto(start_page - pages_to_download + 1) do |page|
            updated_pages << playlist_tracks(favourite_playlist_id, page: page)
          end
          updated_pages.flatten!.map! { |e| e['id'] }
          updated_pages.dup.shift(new_tracks_count).each do |new_track|
            file << new_track
          end
          FileHelper.save_file(file, filename: filename, extension: :json)
        end
        file
      else
        puts 'Loading favourite tracks from Deezer...'
        @favourite_tracks_ids = playlist_tracks(favourite_playlist_id, all: true).map { |e| e['id'] }
        FileHelper.save_file(@favourite_tracks_ids, filename: filename, extension: :json)
        @favourite_tracks_ids
      end
    end
  end
end
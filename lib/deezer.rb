module LastDeezerFm
  class Deezer

    def initialize(api_key, secret_key)
      @api_key = api_key
      @secret_key = secret_key
      auth
      puts 'Loading favourite tracks from Deezer...'
      @favourite_playlist_id = playlists.detect { |e| e['is_loved_track'] }['id']
      @favourite_tracks_ids = playlist_tracks(@favourite_playlist_id, all: true).map { |e| e['id'] }
    end

    # возввращает плейлисты текущего пользователя
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

    # возвращает 'true', если тречок добавился
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

    # возвращает массив с треками
    def playlist_tracks(playlist_id, next_url: nil, all: false)
      uri = next_url.nil? ? "https://api.deezer.com/playlist/#{playlist_id}/tracks" : next_url
      headers = {params: {access_token: @access_token}}

      if all
        iterator_wrapper(__method__, playlist_id, next_url: uri)
      else
        response = RestWrapper.perform_request(uri, :get, headers)
        next_url.nil? ? response['data'] : response
      end
    end

    # возвращает id плейлиста
    def create_playlist(name)
      uri = 'https://api.deezer.com/user/me/playlists'
      headers = {params: {access_token: @access_token, title: name}}
      RestWrapper.perform_request(uri, :post, headers) do |success|
        puts "Playlist \"#{name}\" was successfully created." if success
      end
    end

    # возвращает песни в Deezer из поиска
    def find_track(track_name, next_url: nil, all: false)
      uri = next_url.nil? ? 'https://api.deezer.com/search/track' : next_url
      headers = {params: {access_token: @access_token, q: track_name, strict: 'on'}}

      if all
        iterator_wrapper(__method__, track_name, next_url: uri)
      else
        response = RestWrapper.perform_request(uri, :get, headers)
        puts "Track #{track_name} not found in Deezer!" if response['total'].to_i < 1
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

  end
end
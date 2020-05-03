module LastDeezerFm
  class Deezer

    def initialize(api_key, secret_key)
      @api_key = api_key
      @secret_key = secret_key
      auth
    end

    # возввращает плейлисты текущего пользователя
    def playlists
      uri = 'https://api.deezer.com/user/me/playlists'
      headers = {params: {access_token: @access_token}}
      RestWrapper.perform_request(uri, :get, headers)
    end

    # возвращает 'true', если тречок добавился
    def add_track_to_playlist(playlist_id:, track_id:, &block)
      uri = "https://api.deezer.com/playlist/#{playlist_id}/tracks"
      headers = {params: {access_token: @access_token, songs: track_id}}
      RestWrapper.perform_request(uri, :post, headers, &block)
    end

    # возвращает массив с треками
    def playlist_tracks(playlist_id, next_url: nil)
      uri = next_url.nil? ? "https://api.deezer.com/playlist/#{playlist_id}/tracks" : next_url
      headers = {params: {access_token: @access_token}}
      RestWrapper.perform_request(uri, :get, headers)
    end

    def last_playlist_track(playlist_id)
      response = playlist_tracks(playlist_id)
      while response.key?('next')
        response = playlist_tracks(playlist_id, next_url: response['next'])
      end
      response['data'].last
    end

    # возвращает массив с id треков
    def all_playlist_tracks(playlist_id)
      responses = []
      response = playlist_tracks(playlist_id)
      responses << response
      while response.key?('next')
        response = playlist_tracks(playlist_id, next_url: response['next'])
        responses << response
      end
      responses.map { |e| e['data'] }.flatten.map { |e| e['id'] }
    end

    # возвращает id плейлиста
    def create_playlist(name)
      uri = 'https://api.deezer.com/user/me/playlists'
      headers = {params: {access_token: @access_token, title: name}}
      RestWrapper.perform_request(uri, :post, headers) do |success|
        puts "Создан плейлист \"#{name}\" с id #{response['id']}." if success
      end
    end

    # возвращает песни в Deezer из поиска
    def find_track(track_name)
      uri = 'https://api.deezer.com/search/track'
      headers = {params: {access_token: @access_token, q: track_name, strict: 'on'}}
      response = RestWrapper.perform_request(uri, :get, headers)
      puts "Трек #{track_name} не был найден!" if response['total'].to_i < 1
      response['data']
    end

    def like_track(track_id, &block)
      uri = 'https://api.deezer.com/user/me/tracks'
      headers = {params: {track_id: track_id, access_token: @access_token}}
      RestWrapper.perform_request(uri, :post, headers, &block)
    end

    private

    def auth
      unless auth_valid?
        puts 'Авторизуемся...'
        permissions = %w[basic_access manage_library delete_library]
        uri = "https://connect.deezer.com/oauth/auth.php?app_id=#{@api_key}&redirect_uri=#{DEEZER_REDIRECT_URI}&perms=#{permissions.join(',')}"
        Launchy.open(uri)
        print 'Введите код из адресной строки: '
        @code = STDIN.gets.chomp
        access_token_uri = 'https://connect.deezer.com/oauth/access_token.php'
        headers = {params: {app_id: @api_key, secret: @secret_key, code: @code}}
        response = RestWrapper.perform_request(access_token_uri, :get, headers)
        begin
          response = Hash[*response.split('&').collect { |i| i.split('=') }.flatten]
        rescue StandardError
          raise "Пришёл некорректный ответ \"#{response}\"."
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
            puts 'Сохранённый access token всё ещё действителен, используем его.'
            return true
          else
            return false
          end
        end
      else
        false
      end
    end

  end
end
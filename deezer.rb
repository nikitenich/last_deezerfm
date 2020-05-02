module LastDeezerFm
  class Deezer
    @code
    @access_token

    def initialize(api_key, secret_key)
      @api_key = api_key
      @secret_key = secret_key
      auth
    end

    # возввращает плейлисты текущего пользователя
    def playlists
      uri = 'https://api.deezer.com/user/me/playlists'
      JSON.parse(RestClient.get(uri, {params: {:access_token => @access_token}}))
    end

    # возвращает 'true', если тречок добавился
    def add_track_to_playlist(playlist_id:, track_id:)
      uri = "https://api.deezer.com/playlist/#{playlist_id}/tracks"
      response = JSON.parse(RestClient.post(uri, {}, {params: {:access_token => @access_token, :songs => track_id}}))
      response if success_response?(response) do |success|
        puts response['error']['message'] unless success
      end
    end

    # возвращает массив с треками
    def playlist_tracks(playlist_id, next_url: nil)
      uri = next_url.nil? ? "https://api.deezer.com/playlist/#{playlist_id}/tracks" : next_url
      response = JSON.parse(RestClient.get(uri, {params: {:access_token => @access_token}}))
      response if success_response?(response, true)
    end

    def last_playlist_track(playlist_id)
      response = playlist_tracks(playlist_id)
      while response.has_key?('next')
        response = playlist_tracks(playlist_id, next_url: response['next'])
      end
      response['data'].last
    end

    # возвращает id плейлиста
    def create_playlist(name)
      uri = 'https://api.deezer.com/user/me/playlists'
      response = JSON.parse(RestClient.post(uri, {}, {params: {:access_token => @access_token, :title => name}}))
      response['id'] if success_response?(response, true) do |success|
        puts "Создан плейлист \"#{name}\" с id #{response['id']}." if success
      end
    end

    # возвращает id песни в Deezer
    def find_track(track_name)
      uri = 'https://api.deezer.com/search/track'
      response = JSON.parse(RestClient.get(uri, {params: {:access_token => @access_token, :q => track_name, :strict => 'on'}}))
      if success_response?(response, true)
        if response['total'].to_i < 1
          puts "Трек #{track_name} не был найден!"
        end
        response['data']
      end
    end

    private

    def auth
      unless auth_valid?
        puts "Авторизуемся..."
        permissions = %w[basic_access manage_library delete_library]
        uri = "https://connect.deezer.com/oauth/auth.php?app_id=#{@api_key}&redirect_uri=#{DEEZER_REDIRECT_URI}&perms=#{permissions.join(',')}"
        Launchy.open(uri)
        print "Введите код из адресной строки: "
        @code = STDIN.gets.chomp
        access_token_uri = "https://connect.deezer.com/oauth/access_token.php"
        response = RestClient.get(access_token_uri, {params: {:app_id => @api_key, :secret => @secret_key, :code => @code}})
        begin
          response = Hash[*response.split('&').collect { |i| i.split('=') }.flatten]
        rescue
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
        response = JSON.parse(RestClient.get(uri, {params: {:access_token => possible_token}}))
        success_response?(response) do |success|
          if success
            @access_token = possible_token
            puts "Сохранённый access token всё ещё действителен, используем его."
          end
        end
      else
        false
      end
    end

    def success_response?(response, raise_on_error = false)
      result = case response
               when Hash
                 !response.has_key?('error')
               when String
                 response == 'true'
               when TrueClass
                 response
               when FalseClass
                 response
               end
      yield result if block_given?
      if raise_on_error && !result
        raise "Возникла ошибка при выполнении запроса. Ответ:\n#{response}"
      end
      result
    end
  end
end
module LastDeezerFm
  class RestWrapper
    class << self

      def perform_request(url, type, headers, payload = {}, should_success = false)
        response = if [:delete, :put, :post].include?(type)
                     RestClient::Request.execute(url: url,
                                                 method: type,
                                                 payload: payload,
                                                 headers: headers)
                   else
                     RestClient::Request.execute(url: url,
                                                 method: type,
                                                 headers: headers)
                   end
        parsed = begin
                   JSON.parse(response)
                 rescue
                   response
                 end
        success_status = success_response?(parsed)
        unless success_status
          if should_success
            raise "#{type.to_s.upcase}-запрос вернул ошибку:\n#{parsed['error']}"
          else
            puts "#{type.to_s.upcase}-запрос вернул ошибку:\n#{parsed['error']}"
          end
        end
        yield success_status if block_given?
        parsed
      rescue RestClient::Exception => e
        raise "Ошибка при отправке GET #{url}:\n" + e.to_s + "\nОтвет: #{e.response}\nНагрузка: #{payload}\nЗаголовки: #{headers}"
      end

      def success_response?(response)
        case response
        when Hash
          !response.key?('error')
        when String
          response == 'true'
        when TrueClass
          response
        when FalseClass
          response
        end
      end

    end
  end
end

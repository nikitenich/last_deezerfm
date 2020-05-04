class RestWrapper
  require 'rest-client'

  class << self

    def perform_request(url, type, headers, payload = {}, should_success = false)
      response = if %i[delete put post].include?(type)
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
          raise "#{type.to_s.upcase} request returned an error:\n#{parsed['error']}"
        else
          puts "#{type.to_s.upcase} request returned an error:\n#{parsed['error']}"
        end
      end
      yield success_status if block_given?
      parsed
    rescue RestClient::Exception => e
      raise "Error while sending GET request #{url}:\n" + e.to_s + "\nResponse: #{e.response}\nPayload: #{payload}\nHeaders: #{headers}"
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

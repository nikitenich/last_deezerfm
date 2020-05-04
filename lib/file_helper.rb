module LastDeezerFm
  class FileHelper
    FILES_PATH = 'files'.freeze

    class << self
      def save_file(entity, filename: caller[0][/`.*'/][1..-2], extension: :json, mode: 'w')
        Dir.mkdir(FILES_PATH) unless Dir.exist?(FILES_PATH)
        File.open("#{FILES_PATH}/#{filename}.#{extension.to_s}", mode) do |file|
          if block_given?
            yield file
          else
            case extension
            when :json
              file.write entity.to_json
            when :txt
              file.puts entity
            end
          end
        end
      end

      def file_exists?(filename: caller[0][/`.*'/][1..-2], extension: :json)
        File.exist?("#{FILES_PATH}/#{filename}.#{extension.to_s}")
      end

      def read_file(filename: caller[0][/`.*'/][1..-2], extension: :json)
        file = File.read(FILES_PATH + '/' + filename + '.' + extension.to_s)
        case extension
        when :json
          JSON.parse(file)
        when :txt
          file.to_s.chomp
        end
      end

      def lputs(string, uid)
        filename = caller[0][/`.*'/][1..-2]
        File.open("#{FILES_PATH}/#{filename}-#{uid}.txt", 'a') do |file|
          file.puts string
        end
        puts string
      end
    end

  end
end
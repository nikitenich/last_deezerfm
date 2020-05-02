module LastDeezerFm
  class FileHelper
    @path = 'files'.freeze

    def self.save_file(entity, filename: caller[0][/`.*'/][1..-2], extension: :json, mode: 'w')
      Dir.mkdir(@path) unless Dir.exist?(@path)
      File.open("#{@path}/#{filename}.#{extension.to_s}", mode) do |file|
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

    def self.file_exists?(filename: caller[0][/`.*'/][1..-2], extension: :json)
      File.exist?("#{@path}/#{filename}.#{extension.to_s}")
    end

    def self.read_file(filename: caller[0][/`.*'/][1..-2], extension: :json)
      file = File.read(@path + '/' + filename + '.' + extension.to_s)
      case extension
      when :json
        JSON.parse(file)
      when :txt
        file.to_s.chomp
      end
    end

    def self.lputs(string, uid)
      filename = caller[0][/`.*'/][1..-2]
      File.open("#{@path}/#{filename}-#{uid}.txt", "a") do |file|
        file.puts string
      end
      puts string
    end
  end
end
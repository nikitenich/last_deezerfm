require 'text'
module LastDeezerFm
  class TextHelper

    def self.names_similar?(s1, s2)
      includes = includes?(s1, s2)
      includes ? includes : similarity(s1, s2)
    end

    def self.includes?(s1, s2)
      [s1.include?(s2), s2.include?(s1)].any?
    end

    def self.similarity(s1, s2)
      res = Text::WhiteSimilarity.similarity(s1, s2)
      res > 0.5
    end

  end

end

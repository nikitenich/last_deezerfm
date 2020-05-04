module LastDeezerFm
  class TextHelper
    require 'text'

    class << self
      def names_similar?(s1, s2)
        includes = includes?(s1, s2)
        includes ? includes : similarity(s1, s2)
      end

      def includes?(s1, s2)
        [s1.include?(s2), s2.include?(s1)].any?
      end

      def similarity(s1, s2)
        res = Text::WhiteSimilarity.similarity(s1, s2)
        res > 0.5
      end
    end
  end
end

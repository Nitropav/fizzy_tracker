module MagicLink::Code
  ALPHABET = %w[0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K M N P Q R S T U V W X Y Z].freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      Array.new(length) { ALPHABET[SecureRandom.random_number(ALPHABET.length)] }.join
    end

    def sanitize(code)
      if code.present?
        normalize_code(code)
          .then { apply_substitutions(it) }
          .then { remove_invalid_characters(it) }
      end
    end

    private
      def normalize_code(code)
        code.to_s.upcase
      end

      def apply_substitutions(code)
        CODE_SUBSTITUTIONS.reduce(code) { |result, (from, to)| result.gsub(from, to) }
      end

      def remove_invalid_characters(code)
        code.gsub(/[^#{ALPHABET.join}]/, "")
      end
  end
end

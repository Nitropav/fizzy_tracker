# Custom UUID helpers with base36 string representation.
module ActiveRecord
  module Type
    class Uuid < Binary
      BASE36_LENGTH = 25 # 36^25 > 2^128
      CANONICAL_UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      class << self
        def generate
          uuid = SecureRandom.uuid_v7
          hex = uuid.delete("-")
          hex_to_base36(hex)
        end

        def hex_to_base36(hex)
          hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
        end

        def base36_to_hex(base36)
          base36.to_s.to_i(36).to_s(16).rjust(32, "0")
        end

        def base36?(value)
          value.to_s.match?(/\A[0-9a-z]{#{BASE36_LENGTH}}\z/i)
        end

        def canonical?(value)
          value.to_s.match?(CANONICAL_UUID_PATTERN)
        end

        def hex_to_canonical(hex)
          hex = hex.to_s.delete("-").rjust(32, "0")
          "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
        end

        def base36_to_canonical(base36)
          hex_to_canonical(base36_to_hex(base36))
        end

        def canonical_to_base36(canonical)
          hex_to_base36(canonical.to_s.delete("-"))
        end
      end

      def serialize(value)
        return unless value

        binary = Uuid.base36_to_hex(value).scan(/../).map(&:hex).pack("C*")
        super(binary)
      end

      def deserialize(value)
        return unless value

        hex = value.to_s.unpack1("H*")
        Uuid.hex_to_base36(hex)
      end

      def cast(value)
        value
      end
    end

    class NativeUuid < Value
      def type
        :uuid
      end

      def serialize(value)
        return if value.blank?

        value = value.to_s
        return value if Uuid.canonical?(value)

        Uuid.base36_to_canonical(value)
      end

      def deserialize(value)
        return if value.blank?

        value = value.to_s
        return Uuid.canonical_to_base36(value) if Uuid.canonical?(value)

        value
      end

      def cast(value)
        return if value.blank?

        value = value.to_s
        return Uuid.canonical_to_base36(value) if Uuid.canonical?(value)

        value
      end
    end
  end
end

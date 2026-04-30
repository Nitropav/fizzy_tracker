# Apply explicit column limits when defining tables.
#
# For string columns: defaults to 255.
#
# For text columns: converts legacy `size:` options to equivalent limits:
#   - (blank/default): 65,535 (TEXT)
#   - size: :tiny: 255 (TINYTEXT)
#   - size: :medium: 16,777,215 (MEDIUMTEXT)
#   - size: :long: 4,294,967,295 (LONGTEXT)
#
# PostgreSQL has native unlimited text/bytea semantics, so text sizes are
# intentionally ignored there instead of being converted to invalid byte limits.

module TableDefinitionColumnLimits
  TEXT_SIZE_TO_LIMIT = {
    tiny: 255,
    medium: 16_777_215,
    long: 4_294_967_295
  }.freeze

  TEXT_DEFAULT_LIMIT = 65_535
  STRING_DEFAULT_LIMIT = 255

  def column(name, type, **options)
    if type == :string
      options[:limit] ||= STRING_DEFAULT_LIMIT
    end

    if Fizzy.db_adapter.postgres? && (type == :text || type == :binary)
      options.delete(:size)
      return super
    end

    if type == :text || type == :binary
      if options.key?(:size)
        size = options.delete(:size)
        options[:limit] ||= TEXT_SIZE_TO_LIMIT.fetch(size) do
          raise ArgumentError, "Unknown text size: #{size.inspect}. Use :tiny, :medium, or :long"
        end
      elsif type == :text
        options[:limit] ||= TEXT_DEFAULT_LIMIT
      end
    end

    super
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionColumnLimits)
end

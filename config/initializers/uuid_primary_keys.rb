# Automatically use UUID type for all binary(16) columns and generate defaults

module UuidPrimaryKeyDefault
  def load_schema!
    define_uuid_primary_key_pending_default
    super
  end

  private
    def define_uuid_primary_key_pending_default
      if uuid_primary_key?
        pending_attribute_modifications << PendingUuidDefault.new(primary_key)
      end
    rescue ActiveRecord::StatementInvalid
      # Table doesn't exist yet
    end

    def uuid_primary_key?
      table_name && primary_key && schema_cache.columns_hash(table_name)[primary_key]&.type == :uuid
    end

    PendingUuidDefault = Struct.new(:name) do
      def apply_to(attribute_set)
        attribute_set[name] = attribute_set[name].with_user_default(-> { ActiveRecord::Type::Uuid.generate })
      end
    end
end

module PostgresUuidAdapter
  def lookup_cast_type(sql_type)
    if sql_type == "uuid"
      ActiveRecord::Type::NativeUuid.new
    else
      super
    end
  end
end

module PostgresOidUuidBase36
  def serialize(value)
    ActiveRecord::Type::NativeUuid.new.serialize(value)
  end

  def deserialize(value)
    ActiveRecord::Type::NativeUuid.new.deserialize(value)
  end

  def changed?(old_value, new_value, _new_value_before_type_cast)
    serialize(old_value) != serialize(new_value)
  end

  def changed_in_place?(raw_old_value, new_value)
    serialize(raw_old_value) != serialize(new_value)
  end

  private
    def cast_value(value)
      ActiveRecord::Type::NativeUuid.new.cast(value)
    end
end

module TableDefinitionUuidSupport
  def uuid(name, **options)
    column(name, :uuid, **options)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.prepend(UuidPrimaryKeyDefault)
  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionUuidSupport)
end

ActiveSupport.on_load(:active_record_postgresqladapter) do
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgresUuidAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid.prepend(PostgresOidUuidBase36)
end

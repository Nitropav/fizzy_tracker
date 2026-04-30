# frozen_string_literal: true

module PostgresDateArithmetic
  def date_subtract(date_column, seconds_expression)
    "(#{date_column})::timestamp - ((#{seconds_expression}) * INTERVAL '1 second')"
  end
end

ActiveSupport.on_load(:active_record) do
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgresDateArithmetic)
  end
end

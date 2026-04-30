module Fizzy
  class << self
    def saas?
      false
    end

    def db_adapter
      @db_adapter ||= DbAdapter.new
    end

    def configure_bundle
      nil
    end
  end

  class DbAdapter
    def initialize
      @name = "postgres"
    end

    def to_s
      @name
    end

    def postgres?
      @name == "postgres"
    end
  end
end

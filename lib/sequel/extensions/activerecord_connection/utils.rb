module Sequel
  module ActiveRecordConnection
    module Utils
      def self.set_value(object, name, new_value)
        original_value = object.send(name)
        object.send(:"#{name}=", new_value)
        yield
      ensure
        object.send(:"#{name}=", original_value)
      end

      def self.add_prepared_statements_cache(conn)
        return if conn.respond_to?(:prepared_statements)

        class << conn
          attr_accessor :prepared_statements
        end
        conn.prepared_statements = {}
      end
    end
  end
end

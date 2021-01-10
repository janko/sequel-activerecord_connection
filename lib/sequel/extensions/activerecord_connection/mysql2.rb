require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Mysql2
      def synchronize(*)
        super do |conn|
          if conn.instance_variable_defined?(:@sequel_default_query_options)
            return yield(conn)
          end

          # required for prepared statements
          conn.instance_variable_set(:@sequel_default_query_options, conn.query_options.dup)
          Utils.add_prepared_statements_cache(conn)

          conn.query_options.merge!(as: :hash, symbolize_keys: true, cache_rows: false)

          begin
            yield conn
          ensure
            conn.query_options.replace(conn.remove_instance_variable(:@sequel_default_query_options))
          end
        end
      end
    end
  end
end

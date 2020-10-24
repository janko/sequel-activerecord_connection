module Sequel
  module ActiveRecordConnection
    module Mysql2
      def synchronize(*)
        super do |conn|
          # required for prepared statements
          conn.instance_variable_set(:@sequel_default_query_options, conn.query_options.dup)
          Utils.add_prepared_statements_cache(conn)

          conn.query_options.merge!(as: :hash, symbolize_keys: true, cache_rows: false)

          begin
            yield conn
          ensure
            conn.query_options.replace(conn.instance_variable_get(:@sequel_default_query_options))
          end
        end
      end
    end
  end
end

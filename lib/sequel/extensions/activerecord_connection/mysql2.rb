require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Mysql2
      def synchronize(*)
        super do |conn|
          # required for prepared statements
          Utils.add_prepared_statements_cache(conn)

          yield conn
        end
      end

      private

      def _execute(conn, sql, opts)
        if conn.instance_variable_defined?(:@sequel_default_query_options)
          return super
        end

        conn.instance_variable_set(:@sequel_default_query_options, conn.query_options.dup)
        conn.query_options.merge!(as: :hash, symbolize_keys: true, cache_rows: false)
        begin
          super
        ensure
          conn.query_options.replace(conn.remove_instance_variable(:@sequel_default_query_options))
        end
      end

      def activerecord_connection_class
        ::Mysql2::Client
      end
    end
  end
end

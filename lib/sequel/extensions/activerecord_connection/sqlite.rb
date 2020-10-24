module Sequel
  module ActiveRecordConnection
    module Sqlite
      def self.extended(db)
        if db.timezone == :utc && db.respond_to?(:current_timestamp_utc)
          db.current_timestamp_utc = true
        end
      end

      def execute_ddl(sql, opts = OPTS)
        execute_dui(sql, opts)
      end

      def synchronize(*)
        super do |conn|
          conn.extended_result_codes = true if conn.respond_to?(:extended_result_codes=)

          Utils.set_value(conn, :results_as_hash, nil) do
            yield conn
          end
        end
      end
    end
  end
end

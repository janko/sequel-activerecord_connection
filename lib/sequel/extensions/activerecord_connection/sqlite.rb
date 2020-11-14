require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Sqlite
      def self.extended(db)
        if db.timezone == :utc && db.respond_to?(:current_timestamp_utc)
          db.current_timestamp_utc = true
        end
      end

      def synchronize(*)
        super do |conn|
          conn.extended_result_codes = true if conn.respond_to?(:extended_result_codes=)

          Utils.add_prepared_statements_cache(conn)

          Utils.set_value(conn, :results_as_hash, nil) do
            yield conn
          end
        end
      end
    end
  end
end

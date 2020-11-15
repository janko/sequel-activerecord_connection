require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Oracle
      def synchronize(*)
        super do |conn|
          # required for prepared statements
          Utils.add_prepared_statements_cache(conn.raw_oci_connection)

          yield conn.raw_oci_connection
        end
      end
    end
  end
end

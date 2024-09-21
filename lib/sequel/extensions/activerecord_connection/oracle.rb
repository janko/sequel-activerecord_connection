require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Oracle
      def synchronize(*)
        super do |conn|
          raw_connection = conn.respond_to?(:raw_oci_connection) ? conn.raw_oci_connection : conn

          # required for prepared statements
          Utils.add_prepared_statements_cache(raw_connection)

          yield raw_connection
        end
      end
    end
  end
end

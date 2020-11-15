require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Tinytds
      def synchronize(*)
        super do |conn|
          conn.query_options.merge!(cache_rows: false)

          begin
            yield conn
          ensure
            conn.query_options.merge!(cache_rows: true)
          end
        end
      end
    end
  end
end

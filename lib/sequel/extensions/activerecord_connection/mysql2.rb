module Sequel
  module ActiveRecordConnection
    module Mysql2
      def synchronize(*)
        super do |conn|
          original_query_options = conn.query_options.dup
          conn.query_options.merge!(as: :hash, symbolize_keys: true, cache_rows: false)

          begin
            yield conn
          ensure
            conn.query_options.replace(original_query_options)
          end
        end
      end
    end
  end
end

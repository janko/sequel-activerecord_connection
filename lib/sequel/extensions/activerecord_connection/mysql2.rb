module Sequel
  module ActiveRecordConnection
    module Mysql2
      def execute(sql, opts=OPTS)
        original_query_options = activerecord_raw_connection.query_options.dup

        activerecord_raw_connection.query_options.merge!(
          as:             :hash,
          symbolize_keys: true,
          cache_rows:     false,
        )

        result = activerecord_connection.execute(sql)

        if opts[:type] == :select
          if block_given?
            yield result
          else
            result
          end
        elsif block_given?
          yield activerecord_raw_connection
        end
      rescue ActiveRecord::StatementInvalid => exception
        if exception.cause.is_a?(::Mysql2::Error)
          raise_error(exception.cause)
        else
          raise
        end
      ensure
        activerecord_raw_connection.query_options.replace(original_query_options)
      end
    end
  end
end

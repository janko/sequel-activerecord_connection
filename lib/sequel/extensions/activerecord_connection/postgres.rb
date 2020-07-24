module Sequel
  module ActiveRecordConnection
    module Postgres
      def execute(sql, opts=OPTS)
        result = activerecord_connection.execute(sql)

        if block_given?
          yield result
        else
          result.cmd_tuples
        end
      rescue ActiveRecord::PreparedStatementCacheExpired
        raise # ActiveRecord's transaction manager needs to handle this exception
      rescue ActiveRecord::StatementInvalid => exception
        raise_error(exception.cause, classes: database_error_classes)
      ensure
        result.clear if result
      end

      def transaction(options = {})
        %i[deferrable read_only synchronous].each do |key|
          fail Error, "#{key.inspect} transaction option is currently not supported" if options.key?(key)
        end

        super
      end
    end
  end
end

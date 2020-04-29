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
      rescue ActiveRecord::StatementInvalid => exception
        raise_error(exception.cause, classes: database_error_classes)
      ensure
        result.clear if result
      end
    end
  end
end

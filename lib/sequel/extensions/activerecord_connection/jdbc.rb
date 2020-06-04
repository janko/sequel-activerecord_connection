module Sequel
  module ActiveRecordConnection
    module Jdbc
      def self.extended(db)
        if db.timezone == :utc && db.respond_to?(:current_timestamp_utc)
          db.current_timestamp_utc = true
        end
      end

      def statement(conn)
        stmt = activerecord_raw_connection.connection.createStatement
        yield stmt
      rescue ActiveRecord::StatementInvalid => exception
        raise_error(exception.cause, classes: database_error_classes)
      rescue *database_error_classes => e
        raise_error(e, classes: database_error_classes)
      ensure
        stmt.close if stmt
      end

      def execute(sql, opts=OPTS)
        activerecord_connection.send(:log, sql) do
          super
        end
      rescue ActiveRecord::StatementInvalid => exception
        raise_error(exception.cause, classes: database_error_classes)
      end

      def execute_dui(sql, opts=OPTS)
        activerecord_connection.send(:log, sql) do
          super
        end
      rescue ActiveRecord::StatementInvalid => exception
        raise_error(exception.cause, classes: database_error_classes)
      end
    end
  end
end
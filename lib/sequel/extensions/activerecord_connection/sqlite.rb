module Sequel
  module ActiveRecordConnection
    module Sqlite
      def execute_ddl(sql, opts=OPTS)
        execute(sql, opts)
      end

      private

      # ActiveRecord doesn't send SQLite methods Sequel expects, so we need to
      # try to replicate what ActiveRecord does around connection excecution.
      def _execute(type, sql, opts, &block)
        if activerecord_raw_connection.respond_to?(:extended_result_codes=)
          activerecord_raw_connection.extended_result_codes = true
        end

        if ActiveRecord::VERSION::MAJOR >= 6
          activerecord_connection.materialize_transactions
        end

        activerecord_connection.send(:log, sql) do
          activesupport_interlock do
            case type
            when :select
              activerecord_raw_connection.query(sql, &block)
            when :insert
              activerecord_raw_connection.execute(sql)
              activerecord_raw_connection.last_insert_row_id
            when :update
              activerecord_raw_connection.execute_batch(sql)
              activerecord_raw_connection.changes
            end
          end
        end
      rescue ActiveRecord::StatementInvalid => exception
        if exception.cause.is_a?(SQLite3::Exception)
          raise_error(exception.cause)
        else
          raise exception
        end
      end
    end
  end
end

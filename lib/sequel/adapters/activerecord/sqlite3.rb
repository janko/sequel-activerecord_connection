module Sequel
  module ActiveRecord
    module Sqlite3
      module DatabaseMethods
        def execute_ddl(sql, opts=OPTS)
          execute(sql, opts)
        end

        private

        def _execute(type, sql, opts, &block)
          original_results_as_hash = activerecord_raw_connection.results_as_hash
          activerecord_raw_connection.results_as_hash = false

          case type
          when :select
            activerecord_connection.send(:log, sql) do
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                activerecord_raw_connection.query(sql, &block)
              end
            end
          when :insert
            activerecord_connection.execute(sql)
            activerecord_raw_connection.last_insert_row_id
          when :update
            activerecord_connection.send(:execute_batch, sql)
            activerecord_raw_connection.changes
          end
        rescue ::ActiveRecord::RecordNotUnique => exception
          raise Sequel::UniqueConstraintViolation, exception.cause.message, exception.cause.backtrace
        rescue ::ActiveRecord::StatementInvalid => exception
          if exception.cause.is_a?(SQLite3::Exception)
            raise_error(exception.cause)
          else
            raise
          end
        ensure
          activerecord_raw_connection.results_as_hash = original_results_as_hash
        end
      end

      class Result
        def initialize(array)
          binding.irb
          @array = array
        end

        def types
          return [] if @array.empty?
          @array[0].types
        end

        def columns
          return [] if @array.empty?
          @array[0].fields
        end

        def each(&block)
          @array.each(&block)
        end
      end
    end
  end
end

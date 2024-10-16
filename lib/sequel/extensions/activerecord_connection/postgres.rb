require_relative "utils"

module Sequel
  module ActiveRecordConnection
    module Postgres
      def synchronize(*)
        super do |conn|
          conn.extend(ConnectionMethods)
          conn.instance_variable_set(:@db, self)

          Utils.add_prepared_statements_cache(conn)

          # compatibility for pg_streaming database extension from sequel_pg gem
          if defined?(Sequel::Postgres::Streaming) && is_a?(Sequel::Postgres::Streaming)
            conn.extend(Sequel::Postgres::Streaming::AdapterMethods)
          end

          yield conn
        end
      end

      # Reject unsupported Postgres-specific transaction options.
      def transaction(opts = OPTS)
        %i[deferrable read_only synchronous].each do |key|
          fail Error, "#{key.inspect} transaction option is currently not supported" if opts.key?(key)
        end

        super do |conn|
          yield conn
        rescue => e
          activerecord_connection.clear_cache! if e.class.name == "ActiveRecord::PreparedStatementCacheExpired"
          raise
        end
      end

      private

      def _execute(conn, *)
        Utils.set_value(conn, :type_map_for_results, PG::TypeMapAllStrings.new) do
          super
        end
      end

      def activerecord_connection_class
        ::PG::Connection
      end

      # Copy-pasted from Sequel::Postgres::Adapter.
      module ConnectionMethods
        # The underlying exception classes to reraise as disconnect errors
        # instead of regular database errors.
        DISCONNECT_ERROR_CLASSES = Sequel::Postgres::Adapter::DISCONNECT_ERROR_CLASSES

        # Since exception class based disconnect checking may not work,
        # also trying parsing the exception message to look for disconnect
        # errors.
        DISCONNECT_ERROR_REGEX = Sequel::Postgres::Adapter::DISCONNECT_ERROR_RE

        def async_exec_params(sql, args)
          defined?(super) ? super : async_exec(sql, args)
        end

        # Raise a Sequel::DatabaseDisconnectError if a one of the disconnect
        # error classes is raised, or a PG::Error is raised and the connection
        # status cannot be determined or it is not OK.
        def check_disconnect_errors
          begin
            yield
          rescue *DISCONNECT_ERROR_CLASSES => e
            disconnect = true
            raise(Sequel.convert_exception_class(e, Sequel::DatabaseDisconnectError))
          rescue PG::Error => e
            disconnect = false
            begin
              s = status
            rescue PG::Error
              disconnect = true
            end
            status_ok = (s == PG::CONNECTION_OK)
            disconnect ||= !status_ok
            disconnect ||= e.message =~ DISCONNECT_ERROR_REGEX
            disconnect ? raise(Sequel.convert_exception_class(e, Sequel::DatabaseDisconnectError)) : raise
          ensure
            block if status_ok && !disconnect
          end
        end

        # Execute the given SQL with this connection.  If a block is given,
        # yield the results, otherwise, return the number of changed rows.
        def execute(sql, args = nil)
          args   = args.map { |v| @db.bound_variable_arg(v, self) } if args
          q = check_disconnect_errors { execute_query(sql, args) }

          block_given? ? yield(q) : q.cmd_tuples
        ensure
          q.clear if q && q.respond_to?(:clear)
        end

        private

        # Return the PG::Result containing the query results.
        def execute_query(sql, args)
          @db.log_connection_yield(sql, self, args) do
            args ? async_exec_params(sql, args) : async_exec(sql)
          end
        end
      end
    end
  end
end

require "active_record"

module Sequel
  module ActiveRecord
    module DatabaseMethods
      # Ensure Sequel is not creating its own connection anywhere.
      def connect(*)
        raise Sequel::ActiveRecord::Error, "creating a Sequel connection is not allowed"
      end

      def transaction(savepoint: nil, rollback: nil, auto_savepoint: nil, server: nil, **options)
        activerecord_not_supported!("#{options} transaction options") if options.any?

        if in_transaction?
          requires_new = savepoint || Thread.current[:sequel_activerecord_auto_savepoint]
        else
          requires_new = true
        end

        activerecord_model.transaction(requires_new: requires_new) do
          begin
            Thread.current[:sequel_activerecord_auto_savepoint] = true if auto_savepoint
            yield
          rescue Sequel::Rollback => exception
            raise if rollback == :reraise
            raise ::ActiveRecord::Rollback, exception.message, exception.backtrace
          ensure
            Thread.current[:sequel_activerecord_auto_savepoint] = nil if auto_savepoint
          end

          raise ::ActiveRecord::Rollback if rollback == :always
        end
      end

      def in_transaction?(*)
        activerecord_connection.transaction_open?
      end

      %i[after_commit after_rollback rollback_on_exit rollback_checker].each do |meth|
        define_method(meth) { |*| activerecord_not_supported!("Database##{meth}") }
      end

      def synchronize(*)
        activerecord_connection.lock.synchronize do
          yield activerecord_raw_connection
        end
      end

      def timezone
        @timezone || activerecord_model.default_timezone || Sequel.database_timezone
      end

      private

      # We won't be needing a real connection pool.
      def connection_pool_default_options
        { pool_class: Sequel::ConnectionPool }
      end

      def activerecord_raw_connection
        activerecord_connection.raw_connection
      end

      def activerecord_connection
        activerecord_model.connection
      end

      def activerecord_model
        opts[:activerecord_model]
      end

      def activerecord_not_supported!(feature)
        fail Sequel::ActiveRecord::Error, "#{feature} is currently not supported by ActiveRecord adapter"
      end
    end
  end
end

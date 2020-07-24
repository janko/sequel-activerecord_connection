module Sequel
  module ActiveRecordConnection
    Error = Class.new(Sequel::Error)

    TRANSACTION_ISOLATION_MAP = {
      uncommitted:  :read_uncommitted,
      committed:    :read_committed,
      repeatable:   :repeatable_read,
      serializable: :serializable,
    }

    def self.extended(db)
      db.activerecord_model = ActiveRecord::Base
      db.timezone = ActiveRecord::Base.default_timezone

      begin
        require "sequel/extensions/activerecord_connection/#{db.adapter_scheme}"
        db.extend Sequel::ActiveRecordConnection.const_get(db.adapter_scheme.capitalize)
      rescue LoadError
        fail Error, "unsupported adapter: #{db.adapter_scheme}"
      end
    end

    attr_accessor :activerecord_model

    # Ensure Sequel is not creating its own connection anywhere.
    def connect(*)
      raise Error, "creating a Sequel connection is not allowed"
    end

    # Avoid calling Sequel's connection pool, instead use ActiveRecord.
    def synchronize(*)
      if ActiveRecord.version >= Gem::Version.new("5.1.0")
        activerecord_connection.lock.synchronize do
          yield activerecord_raw_connection
        end
      else
        yield activerecord_raw_connection
      end
    end

    private

    # Backfills any ActiveRecord transactions/savepoints that have been opened
    # directly via ActiveRecord::Base.transaction. Sequel uses this information
    # to know whether we're in a transaction, whether to create a savepoint,
    # when to run transaction/savepoint hooks etc.
    def _trans(conn)
      Sequel.synchronize do
        result = @transactions[conn]

        if activerecord_connection.transaction_open?
          result ||= { savepoints: [] }
          while result[:savepoints].length < activerecord_connection.open_transactions
            result[:savepoints].unshift({ activerecord: true })
          end
        end

        @transactions[conn] = result if result
        result
      end
    end

    # First delete any transactions/savepoints opened directly via
    # ActiveRecord::Base.transaction, so that Sequel can detect when the last
    # Sequel transaction has been closed and clear transaction information.
    def transaction_finished?(conn)
      _trans(conn)[:savepoints].shift while _trans(conn)[:savepoints].first[:activerecord]
      super
    end

    def begin_transaction(conn, opts = {})
      isolation = TRANSACTION_ISOLATION_MAP.fetch(opts[:isolation]) if opts[:isolation]

      activerecord_connection.begin_transaction(isolation: isolation)
    end

    def commit_transaction(conn, opts = {})
      activerecord_connection.commit_transaction
    end

    def rollback_transaction(conn, opts = {})
      activerecord_connection.rollback_transaction
      activerecord_connection.transaction_manager.send(:after_failure_actions, activerecord_connection.current_transaction, $!) if activerecord_connection.transaction_manager.respond_to?(:after_failure_actions)
    end

    def savepoint_level(conn)
      activerecord_connection.open_transactions
    end

    def activerecord_raw_connection
      activerecord_connection.raw_connection
    end

    def activerecord_connection
      activerecord_model.connection
    end

    def activesupport_interlock(&block)
      if ActiveSupport::Dependencies.respond_to?(:interlock)
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads(&block)
      else
        yield
      end
    end
  end

  Database.register_extension(:activerecord_connection, ActiveRecordConnection)
end

# frozen_string_literal: true

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

    # Synchronizes transaction state with ActiveRecord. Sequel uses this
    # information to know whether we're in a transaction, whether to create a
    # savepoint, when to run transaction/savepoint hooks etc.
    def _trans(conn)
      hash = super || { savepoints: [], activerecord: true }

      # add any ActiveRecord transactions/savepoints that have been opened
      # directly via ActiveRecord::Base.transaction
      while hash[:savepoints].length < activerecord_connection.open_transactions
        hash[:savepoints] << { activerecord: true }
      end

      # remove any ActiveRecord transactions/savepoints that have been closed
      # directly via ActiveRecord::Base.transaction
      while hash[:savepoints].length > activerecord_connection.open_transactions && hash[:savepoints].last[:activerecord]
        hash[:savepoints].pop
      end

      # sync knowledge about joinability of current transaction/savepoint
      if activerecord_connection.transaction_open? && !activerecord_connection.current_transaction.joinable?
        hash[:savepoints].last[:auto_savepoint] = true
      end

      if hash[:savepoints].empty? && hash[:activerecord]
        Sequel.synchronize { @transactions.delete(conn) }
      else
        Sequel.synchronize { @transactions[conn] = hash }
      end

      super
    end

    def begin_transaction(conn, opts = {})
      isolation = TRANSACTION_ISOLATION_MAP.fetch(opts[:isolation]) if opts[:isolation]
      joinable  = !opts[:auto_savepoint]

      activerecord_connection.begin_transaction(isolation: isolation, joinable: joinable)
    end

    def commit_transaction(conn, opts = {})
      activerecord_connection.commit_transaction
    end

    def rollback_transaction(conn, opts = {})
      activerecord_connection.rollback_transaction
      activerecord_connection.transaction_manager.send(:after_failure_actions, activerecord_connection.current_transaction, $!) if activerecord_connection.transaction_manager.respond_to?(:after_failure_actions)
    end

    def add_transaction_hook(conn, type, block)
      if _trans(conn)[:activerecord]
        fail Error, "cannot add transaction hook when ActiveRecord holds the outer transaction"
      end

      super
    end

    def add_savepoint_hook(conn, type, block)
      if _trans(conn)[:savepoints].last[:activerecord]
        fail Error, "cannot add savepoint hook when ActiveRecord holds the current savepoint"
      end

      super
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

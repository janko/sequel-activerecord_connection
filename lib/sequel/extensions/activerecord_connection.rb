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
        # assume the Sequel adapter already works with Active Record
      end
    end

    attr_accessor :activerecord_model

    # Ensure Sequel is not creating its own connection anywhere.
    def connect(*)
      raise Error, "creating a Sequel connection is not allowed"
    end

    # Avoid calling Sequel's connection pool, instead use Active Record's.
    def synchronize(*)
      yield activerecord_connection.raw_connection
    end

    # Log executed queries into Active Record logger as well.
    def log_connection_yield(sql, *)
      activerecord_log(sql) { super }
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

      # sync knowledge about joinability of current ActiveRecord transaction/savepoint
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

    def begin_transaction(conn, opts = OPTS)
      isolation = TRANSACTION_ISOLATION_MAP.fetch(opts[:isolation]) if opts[:isolation]
      joinable  = !opts[:auto_savepoint]

      activerecord_connection.begin_transaction(isolation: isolation, joinable: joinable)
    end

    def commit_transaction(conn, opts = OPTS)
      activerecord_connection.commit_transaction
    end

    def rollback_transaction(conn, opts = OPTS)
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

    def activerecord_connection
      activerecord_model.connection
    end

    def activerecord_log(sql, &block)
      ActiveSupport::Notifications.instrument("sql.active_record", sql: sql, name: "Sequel", &block)
    end

    module Utils
      def self.set_value(object, name, new_value)
        original_value = object.send(name)
        object.send(:"#{name}=", new_value)
        yield
      ensure
        object.send(:"#{name}=", original_value)
      end

      def self.add_prepared_statements_cache(conn)
        return if conn.respond_to?(:prepared_statements)

        class << conn
          attr_accessor :prepared_statements
        end
        conn.prepared_statements = {}
      end
    end
  end

  Database.register_extension(:activerecord_connection, ActiveRecordConnection)
end

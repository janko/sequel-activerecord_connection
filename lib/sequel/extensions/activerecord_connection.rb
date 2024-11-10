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
      db.opts[:test] = false unless db.opts.key?(:test)
      db.instance_variable_set(:@transactions, {}) if RUBY_ENGINE == "jruby"

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

    def extension(*)
      super
    rescue ActiveRecord::NoDatabaseError
      warn "Sequel database extension #{@loaded_extensions.last.inspect} failed to initialize because there is no database."
    end

    # Avoid calling Sequel's connection pool, instead use Active Record's.
    def synchronize(*)
      activerecord_synchronize do
        conn = activerecord_connection.raw_connection

        if activerecord_connection_class && !conn.is_a?(activerecord_connection_class)
          fail Error, "expected Active Record connection to be a #{activerecord_connection_class}, got #{conn.class}"
        end

        yield conn
      ensure
        clear_activerecord_query_cache
      end
    end

    # Log executed queries into Active Record logger as well.
    def log_connection_yield(sql, conn, args = nil)
      sql += "; #{args.inspect}" if args

      activerecord_log(sql) { super }
    end

    # Match database timezone with Active Record.
    def timezone
      @timezone || activerecord_timezone
    end

    private

    # Synchronizes transaction state with ActiveRecord. Sequel uses this
    # information to know whether we're in a transaction, whether to create a
    # savepoint, when to run transaction/savepoint hooks etc.
    def _trans(conn)
      hash = super || { activerecord: true }

      # adapters that don't support savepoints won't have this assigned
      hash[:savepoints] ||= []

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
    end

    # When Active Record holds the transaction, we cannot use Sequel hooks,
    # because Sequel doesn't have knowledge of when the transaction is
    # committed. So in this case we register the hook using Active Record.
    def add_transaction_hook(conn, type, block)
      if _trans(conn)[:activerecord]
        activerecord_transaction_callback(type, &block)
      else
        super
      end
    end

    # When Active Record holds the savepoint, we cannot use Sequel hooks,
    # because Sequel doesn't have knowledge of when the savepoint is
    # released. So in this case we register the hook using Active Record.
    def add_savepoint_hook(conn, type, block)
      if _trans(conn)[:savepoints].last[:activerecord]
        activerecord_transaction_callback(type, &block)
      else
        super
      end
    end

    if ActiveRecord.version >= Gem::Version.new("7.2")
      def activerecord_transaction_callback(type, &block)
        activerecord_connection.current_transaction.public_send(type, &block)
      end
    else
      begin
        gem "after_commit_everywhere", "~> 1.1"
        require "after_commit_everywhere"
      rescue LoadError
        fail Error, %q(You need to add `gem "after_commit_everywhere", "~> 1.1"` to your Gemfile when using Active Record < 7.2)
      end

      def activerecord_transaction_callback(type, &block)
        AfterCommitEverywhere.public_send(type, &block)
      end
    end

    # Prevents sql_log_normalizer DB extension from skipping the normalization.
    def skip_logging?
      return false if @loaded_extensions.include?(:sql_log_normalizer)
      super
    end

    def activerecord_synchronize
      with_activerecord_connection do
        activerecord_lock do
          yield
        end
      end
    end

    if ActiveRecord.version >= Gem::Version.new("7.0")
      def clear_activerecord_query_cache
        activerecord_model.clear_query_caches_for_current_thread
      end
    else
      def clear_activerecord_query_cache
        activerecord_connection.clear_query_cache
      end
    end

    if ActiveRecord.version >= Gem::Version.new("7.2")
      def with_activerecord_connection
        activerecord_model.with_connection(prevent_permanent_checkout: true) do
          yield activerecord_connection
        end
      end
    else
      def with_activerecord_connection
        yield activerecord_connection
      end
    end

    # Active Record doesn't guarantee that a single connection can only be used
    # by one thread at a time, so we need to use locking, which is what Active
    # Record does internally as well.
    if ActiveRecord.version >= Gem::Version.new("5.1")
      def activerecord_lock
        activerecord_connection.lock.synchronize do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            yield
          end
        end
      end
    else
      def activerecord_lock
        yield
      end
    end

    def activerecord_connection
      activerecord_model.connection
    end

    def activerecord_connection_class
      # defines in adapter modules
    end

    def activerecord_log(sql, &block)
      ActiveSupport::Notifications.instrument(
        "sql.active_record",
        sql:        sql,
        name:       "Sequel",
        connection: activerecord_connection,
        &block
      )
    end

    if ActiveRecord.version >= Gem::Version.new("7.0")
      def activerecord_timezone
        ActiveRecord.default_timezone
      end
    else
      def activerecord_timezone
        ActiveRecord::Base.default_timezone
      end
    end
  end

  Database.register_extension(:activerecord_connection, ActiveRecordConnection)
end

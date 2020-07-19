module Sequel
  module ActiveRecordConnection
    Error = Class.new(Sequel::Error)

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

    def transaction(options = {})
      %i[isolation num_retries before_retry prepare retry_on].each do |key|
        fail Error, "#{key.inspect} transaction option is currently not supported" if options.key?(key)
      end

      activerecord_model.transaction(requires_new: !in_transaction? || options[:savepoint] || Thread.current[:sequel_activerecord_auto_savepoint]) do
        begin
          Thread.current[:sequel_activerecord_auto_savepoint] = true if options[:auto_savepoint]
          result = yield
          raise ActiveRecord::Rollback if options[:rollback] == :always
          result
        rescue Sequel::Rollback => exception
          raise if options[:rollback] == :reraise
          raise ActiveRecord::Rollback, exception.message, exception.backtrace
        ensure
          Thread.current[:sequel_activerecord_auto_savepoint] = nil if options[:auto_savepoint]
        end
      end
    end

    def in_transaction?(*)
      activerecord_connection.transaction_open?
    end

    %i[after_commit after_rollback rollback_on_exit rollback_checker].each do |meth|
      define_method(meth) do |*|
        fail Error, "Database##{meth} is currently not supported"
      end
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

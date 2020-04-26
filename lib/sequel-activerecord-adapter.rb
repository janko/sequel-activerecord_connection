require "sequel/core"
require "active_record"

require "sequel/adapters/activerecord"

module Sequel
  def self.activerecord(model = nil, **options)
    model ||= ::ActiveRecord::Base

    activerecord_adapter = model.connection_config.fetch(:adapter)

    case activerecord_adapter
    when "postgresql" then adapter ||= :postgres
    when "mysql2"     then adapter ||= :mysql2
    when "sqlite3"    then adapter ||= :sqlite
    else
      raise Sequel::ActiveRecord::Error, "unsupported adapter: #{activerecord_adapter}"
    end

    db = connect(
      adapter:            adapter,
      activerecord_model: model,
      pool_class:         Sequel::ConnectionPool, # fake connection pool
      test:               false, # don't force ActiveRecord connection
      **options,
    )

    # general database extensions
    db.extend Sequel::ActiveRecord::DatabaseMethods

    # adapter-specific database extensions
    Kernel.require "sequel/adapters/activerecord/#{activerecord_adapter}"
    adapter_module = Sequel::ActiveRecord.const_get(activerecord_adapter.capitalize)
    db.extend adapter_module::DatabaseMethods

    db
  end

  module ActiveRecord
    class Error < Sequel::Error
    end
  end
end

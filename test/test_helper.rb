require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "sequel-activerecord-adapter"
require "active_record"

require "stringio"

class Minitest::Test
  def connect(adapter)
    if adapter == "sqlite3"
      ActiveRecord::Base.establish_connection(
        adapter: adapter,
        database: ":memory:",
      )
    else
      ActiveRecord::Base.establish_connection(
        adapter:  adapter,
        database: "sequel_activerecord_adapter_test",
        host:     "localhost",
        username: "sequel_activerecord_adapter_test",
        password: "sequel_activerecord_adapter_test",
      )
    end

    @db = Sequel.activerecord
    @db.create_table! :records do
      primary_key :id
      String :col
      Time :time
    end

    @log = StringIO.new
    ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      @log.puts event.payload[:sql]
    end
  end

  def disconnect(*)
    ActiveRecord::Base.remove_connection
  end

  def assert_logged(content)
    assert_includes @log.string, content
  end
end

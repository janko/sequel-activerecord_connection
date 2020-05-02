require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "active_record"
require "sequel/core"

require "stringio"

class Minitest::Test
  def connect_postgresql
    ActiveRecord::Base.establish_connection(
      adapter:  "postgresql",
      database: "sequel_activerecord_adapter_test",
      username: "sequel_activerecord_adapter_test",
      password: "sequel_activerecord_adapter_test",
    )

    @db = Sequel.postgres(test: false)
    @db.extension :activerecord_connection
  end

  def connect_mysql2
    ActiveRecord::Base.establish_connection(
      adapter:  "mysql2",
      host:     "localhost",
      database: "sequel_activerecord_adapter_test",
      username: "sequel_activerecord_adapter_test",
      password: "sequel_activerecord_adapter_test",
    )

    @db = Sequel.mysql2(test: false)
    @db.extension :activerecord_connection
  end

  def connect_sqlite3
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:",
    )

    @db = Sequel.sqlite(test: false)
    @db.extension :activerecord_connection
  end

  def setup
    ActiveRecord::Base.default_timezone = :utc # reset default setting

    @log = StringIO.new
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)

      @log.puts event.payload[:sql]
    end
  end

  def teardown
    ActiveRecord::Base.remove_connection
  end

  def assert_logged(content)
    assert_includes @log.string, content
  end
end

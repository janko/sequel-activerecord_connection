require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "active_record"
require "sequel/core"
require "sequel/model"

require "stringio"
require "active_support/core_ext/string"

class Minitest::Test
  def connect_postgresql
    if ENV["CI"]
      ActiveRecord::Base.establish_connection(
        adapter:  "postgresql",
        database: "sequel_activerecord_connection",
        username: "postgres",
      )
    else
      ActiveRecord::Base.establish_connection(
        adapter:  "postgresql",
        database: "sequel_activerecord_connection",
        username: "sequel_activerecord_connection",
        password: "sequel_activerecord_connection",
      )
    end

    @db = if RUBY_ENGINE == "jruby"
      Sequel.connect("jdbc:postgresql://", test: false)
    else
      Sequel.postgres(test: false)
    end
    @db.extension :activerecord_connection
  end

  def connect_mysql2
    if ENV["CI"]
      ActiveRecord::Base.establish_connection(
        adapter:  "mysql2",
        host:     "localhost",
        database: "sequel_activerecord_connection",
        username: "root",
      )
    else
      ActiveRecord::Base.establish_connection(
        adapter:  "mysql2",
        host:     "localhost",
        database: "sequel_activerecord_connection",
        username: "sequel_activerecord_connection",
        password: "sequel_activerecord_connection",
      )
    end

    @db = if RUBY_ENGINE == "jruby"
      Sequel.connect("jdbc:mysql://", test: false)
    else
      Sequel.mysql2(test: false)
    end
    @db.extension :activerecord_connection
  end

  def connect_sqlite3
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:",
    )

    @db = if RUBY_ENGINE == "jruby"
      Sequel.connect("jdbc:sqlite://", test: false)
    else
      Sequel.sqlite(test: false)
    end
    @db.extension :activerecord_connection
  end

  def setup
    @log = StringIO.new
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)

      original_pos = @log.pos
      @log.seek(0, IO::SEEK_END)
      @log.puts event.payload[:sql]
      @log.pos = original_pos
    end
  end

  def teardown
    ActiveRecord::Base.remove_connection
    ActiveRecord::Base.default_timezone = :utc # reset default setting
    Sequel::DATABASES.delete(@db)
  end

  def assert_logged(content)
    if RUBY_ENGINE == "jruby"
      content.gsub!(/BEGIN\nSET TRANSACTION ISOLATION LEVEL (.+)/) do
        "BEGIN ISOLATED TRANSACTION - #{$1.downcase.tr(" ", "_")}"
      end
      content.gsub!(/(BEGIN|COMMIT|ROLLBACK)$/, '\1 TRANSACTION')
    end

    assert_includes @log.read, content
  end
end

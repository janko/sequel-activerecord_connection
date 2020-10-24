require "bundler/setup"

if RUBY_VERSION >= "2.4"
  require "warning"
  Warning.ignore(:missing_ivar, Gem::Specification.find_by_name("sequel").load_paths.first)
  Warning.ignore(/Capturing the given block using Proc\.new is deprecated/, Gem::Specification.find_by_name("activesupport").load_paths.first)
  Warning.ignore(/rb_(tainted_str_new(_cstr)?|check_safe_obj) is deprecated/)
end

require "minitest/autorun"
require "minitest/pride"

require "active_record"
require "sequel/core"
require "sequel/model"

require "stringio"
require "active_support/core_ext/string"

class Minitest::Test
  def connect_postgresql
    activerecord_connect(
      adapter:  "postgresql",
      database: "sequel_activerecord_connection",
      **(ENV["CI"] ? { username: "postgres" }
                   : { username: "sequel_activerecord_connection", password: "sequel_activerecord_connection" })
    )

    @db = Sequel.connect "#{"jdbc:" if RUBY_ENGINE == "jruby"}postgresql://",
      extensions: :activerecord_connection
  end

  def connect_mysql2
    activerecord_connect(
      adapter:  "mysql2",
      host:     "localhost",
      database: "sequel_activerecord_connection",
      **(ENV["CI"] ? { username: "root" }
                   : { username: "sequel_activerecord_connection", password: "sequel_activerecord_connection" })
    )

    @db = Sequel.connect (RUBY_ENGINE == "jruby" ? "jdbc:mysql://" : "mysql2://"),
      extensions: :activerecord_connection
  end

  def connect_sqlite3
    activerecord_connect(
      adapter: "sqlite3",
      database: ":memory:",
    )

    @db = Sequel.connect "#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite://",
      extensions: :activerecord_connection
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
    Sequel::DATABASES.delete(@db) if defined?(@db)
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

  def activerecord_connect(**options)
    ActiveRecord::Base.establish_connection(options)
    ActiveRecord::Base.connection.disable_lazy_transactions! if ActiveRecord::VERSION::MAJOR >= 6
  end
end

require "bundler/setup"

require "warning"
Warning.ignore(:missing_ivar, Gem::Specification.find_by_name("sequel").load_paths.first)
Warning.ignore(/Capturing the given block using Proc\.new is deprecated/, Gem::Specification.find_by_name("activesupport").load_paths.first)
Warning.ignore(/rb_(tainted_str_new(_cstr)?|check_safe_obj)/)
Warning.ignore(/deprecated Object#=~ is called on Integer/) # ActiveRecord 4.2

require "minitest/autorun"
require "minitest/pride"

require "active_record"
require "sequel/core"
require "sequel/model"

require "stringio"
require "active_support/core_ext/string"

class Minitest::Test
  def connect_postgresql
    options = {}

    if ENV["CI"]
      options[:host] = "localhost"
    end

    activerecord_connect(
      adapter:  "postgresql",
      database: "sequel_activerecord_connection",
      username: "sequel_activerecord_connection",
      password: "sequel_activerecord_connection",
      **options,
    )

    @db = Sequel.connect "#{"jdbc:" if RUBY_ENGINE == "jruby"}postgresql://",
      extensions: :activerecord_connection
  end

  def connect_mysql2
    options = {}

    if ActiveRecord.version >= Gem::Version.new("7.1.0.alpha")
      options[:prepared_statements] = false
    end

    if ENV["CI"]
      options[:username] = "root"
      options[:host]     = "127.0.0.1"
    else
      options[:username] = "sequel_activerecord_connection"
    end

    if RUBY_ENGINE == "jruby"
      options[:properties] = { allowPublicKeyRetrieval: true }
    end

    activerecord_connect(
      adapter:  "mysql2",
      database: "sequel_activerecord_connection",
      password: "sequel_activerecord_connection",
      **options
    )

    @db = Sequel.connect (RUBY_ENGINE == "jruby" ? "jdbc:mysql://" : "mysql2://"),
      extensions: :activerecord_connection
  end

  def connect_sqlite3
    activerecord_connect(
      adapter: "sqlite3",
      database: ":memory:",
      password: "sequel_activerecord_connection",
      host:     "localhost",
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
    set_activerecord_timezone(:utc) # reset default setting
    Sequel::DATABASES.delete(@db) if defined?(@db)
  end

  def set_activerecord_timezone(value)
    if ActiveRecord::VERSION::MAJOR >= 7
      ActiveRecord.default_timezone = value
    else
      ActiveRecord::Base.default_timezone = value
    end
  end

  def assert_logged(content)
    if RUBY_ENGINE == "jruby"
      transaction = " TRANSACTION" if Gem::Version.new(ArJdbc::VERSION) < Gem::Version.new("61.0")
      content.gsub!(/BEGIN\nSET TRANSACTION ISOLATION LEVEL (.+)/) do
        "BEGIN ISOLATED#{transaction} - #{$1.downcase.tr(" ", "_")}"
      end
      content.gsub!(/(BEGIN|COMMIT|ROLLBACK)$/, "\\1#{transaction}")
    end

    assert_includes @log.read, content
  end

  def activerecord_connect(**options)
    ActiveRecord::Base.establish_connection(options)
    ActiveRecord::Base.connection.disable_lazy_transactions! if ActiveRecord.version >= Gem::Version.new("6.0")
  end

  def activerecord_config
    if ActiveRecord.version >= Gem::Version.new("6.1")
      ActiveRecord::Base.connection_db_config.configuration_hash
    else
      ActiveRecord::Base.connection_config
    end
  end
end

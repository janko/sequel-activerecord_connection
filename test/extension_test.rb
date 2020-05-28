require "test_helper"

describe "General adapter" do
  before do
    connect_postgresql

    @db.create_table! :records do
      primary_key :id
      String :col
      Time :time
    end
  end

  it "calls the transaction" do
    @db.transaction { @db.run "SELECT 1" }

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SELECT 1
      COMMIT#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "reuses exiting transaction by default" do
    @db.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction do
        assert_equal 1, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SELECT 1
      COMMIT#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "opens new transaction when savepoint: :only is passed" do
    @db.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction(savepoint: :only) do
        assert_equal 2, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SAVEPOINT active_record_1
      SELECT 1
      RELEASE SAVEPOINT active_record_1
      COMMIT#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "opens new transaction when savepoint: true is passed" do
    @db.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction(savepoint: true) do
        assert_equal 2, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SAVEPOINT active_record_1
      SELECT 1
      RELEASE SAVEPOINT active_record_1
      COMMIT#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "opens new transaction when auto_savepoint: true is passed" do
    @db.transaction(auto_savepoint: true) do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction do
        assert_equal 2, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SAVEPOINT active_record_1
      SELECT 1
      RELEASE SAVEPOINT active_record_1
      COMMIT#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "rolls back on Sequel::Rollback" do
    @db.transaction do
      @db.run "SELECT 1"
      raise Sequel::Rollback
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SELECT 1
      ROLLBACK#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "always rolls back when rollback: :always was passed" do
    @db.transaction(rollback: :always) do
      @db.run "SELECT 1"
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SELECT 1
      ROLLBACK#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "re-raises rollback exception when rollback: :reraise was passed" do
    assert_raises Sequel::Rollback do
      @db.transaction(rollback: :reraise) do
        @db.run "SELECT 1"
        raise Sequel::Rollback
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
      SELECT 1
      ROLLBACK#{' TRANSACTION' if RUBY_ENGINE == "jruby"}
    SQL
  end

  it "knows when it's in a transaction" do
    assert_equal false, @db.in_transaction?

    @db.transaction do
      assert_equal true, @db.in_transaction?
    end
  end

  it "doesn't support other transaction options" do
    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.transaction(isolation: :committed) { }
    end
  end

  it "doesn't support other transaction methods" do
    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.after_commit {}
    end

    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.after_rollback {}
    end

    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.rollback_on_exit {}
    end

    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.rollback_checker {}
    end
  end

  it "doesn't support Database#connect" do
    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.connect
    end
  end
end

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
      BEGIN
      SELECT 1
      COMMIT
    SQL
  end

  it "returns transaction block result" do
    assert_equal :result, @db.transaction { :result }
  end

  it "knows when it's in a transaction" do
    assert_equal false, @db.in_transaction?
    assert_equal false, ActiveRecord::Base.connection.transaction_open?

    @db.transaction do
      assert_equal true, @db.in_transaction?
      assert_equal true, ActiveRecord::Base.connection.transaction_open?
    end

    ActiveRecord::Base.transaction do
      assert_equal true, @db.in_transaction?
      assert_equal true, ActiveRecord::Base.connection.transaction_open?
    end
  end

  it "reuses existing transaction by default" do
    @db.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction do
        assert_equal 1, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SELECT 1
      COMMIT
    SQL

    @db.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      ActiveRecord::Base.transaction do
        assert_equal 1, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SELECT 1
      COMMIT
    SQL

    ActiveRecord::Base.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction do
        assert_equal 1, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SELECT 1
      COMMIT
    SQL
  end

  it "handles :savepoint option" do
    ActiveRecord::Base.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction(savepoint: :only) do
        assert_equal 2, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SAVEPOINT active_record_1
      SELECT 1
      RELEASE SAVEPOINT active_record_1
      COMMIT
    SQL

    ActiveRecord::Base.transaction do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction(savepoint: true) do
        assert_equal 2, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SAVEPOINT active_record_1
      SELECT 1
      RELEASE SAVEPOINT active_record_1
      COMMIT
    SQL
  end

  it "handles :auto_savepoint option" do
    @db.transaction(auto_savepoint: true) do
      assert_equal 1, ActiveRecord::Base.connection.open_transactions
      @db.transaction do
        assert_equal 2, ActiveRecord::Base.connection.open_transactions
        @db.run "SELECT 1"
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SAVEPOINT active_record_1
      SELECT 1
      RELEASE SAVEPOINT active_record_1
      COMMIT
    SQL
  end

  it "handles :rollback option" do
    @db.transaction(rollback: :always) do
      @db.run "SELECT 1"
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SELECT 1
      ROLLBACK
    SQL

    assert_raises Sequel::Rollback do
      @db.transaction(rollback: :reraise) do
        @db.run "SELECT 1"
        raise Sequel::Rollback
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SELECT 1
      ROLLBACK
    SQL
  end

  it "handles :isolation option" do
    @db.transaction(isolation: :uncommitted) { }

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
      COMMIT
    SQL

    @db.transaction(isolation: :committed) { }

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SET TRANSACTION ISOLATION LEVEL READ COMMITTED
      COMMIT
    SQL

    @db.transaction(isolation: :repeatable) { }

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
      COMMIT
    SQL

    @db.transaction(isolation: :serializable) { }

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
      COMMIT
    SQL
  end

  it "rolls back on exceptions" do
    assert_raises KeyError do
      @db.transaction do
        @db.run "SELECT 1"
        raise KeyError
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SELECT 1
      ROLLBACK
    SQL
  end

  it "rolls back on Sequel::Rollback" do
    @db.transaction do
      raise Sequel::Rollback
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      ROLLBACK
    SQL

    @db.transaction do
      @db.transaction(savepoint: true) do
        raise Sequel::Rollback
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SAVEPOINT active_record_1
      ROLLBACK TO SAVEPOINT active_record_1
      COMMIT
    SQL
  end

  it "supports #after_commit" do
    after_commit_called = nil
    @db.transaction do
      @db.after_commit { after_commit_called = true }
    end
    assert after_commit_called

    after_commit_called = nil
    @db.transaction do
      ActiveRecord::Base.transaction do
        @db.after_commit { after_commit_called = true }
      end
    end
    assert after_commit_called

    after_commit_called = nil
    @db.transaction do
      ActiveRecord::Base.transaction(requires_new: true) do
        @db.after_commit { after_commit_called = true }
      end
    end
    assert after_commit_called

    after_commit_called = nil
    @db.transaction do
      @db.transaction do
        @db.after_commit { after_commit_called = true }
      end
    end
    assert after_commit_called

    after_commit_called = nil
    @db.transaction do
      @db.transaction(savepoint: true) do
        @db.after_commit { after_commit_called = true }
      end
    end
    assert after_commit_called

    after_commit_called = nil
    ActiveRecord::Base.transaction do
      @db.transaction(savepoint: true) do
        @db.after_commit { after_commit_called = true }
      end
    end
    assert after_commit_called
  end

  it "supports #after_rollback" do
    after_rollback_called = nil
    @db.transaction do
      @db.after_rollback { after_rollback_called = true }
      raise Sequel::Rollback
    end
    assert after_rollback_called

    after_rollback_called = nil
    @db.transaction do
      ActiveRecord::Base.transaction do
        @db.after_rollback { after_rollback_called = true }
        raise Sequel::Rollback
      end
    end
    assert after_rollback_called

    after_rollback_called = nil
    @db.transaction do
      ActiveRecord::Base.transaction(requires_new: true) do
        @db.after_rollback { after_rollback_called = true }
        raise Sequel::Rollback
      end
    end
    assert after_rollback_called

    after_rollback_called = nil
    @db.transaction do
      @db.transaction do
        @db.after_rollback { after_rollback_called = true }
        raise Sequel::Rollback
      end
    end
    assert after_rollback_called

    after_rollback_called = nil
    @db.transaction do
      @db.transaction(savepoint: true) do
        @db.after_rollback { after_rollback_called = true }
        raise Sequel::Rollback
      end
    end
    assert after_rollback_called

    after_rollback_called = nil
    ActiveRecord::Base.transaction do
      @db.transaction(savepoint: true) do
        @db.after_rollback { after_rollback_called = true }
        raise Sequel::Rollback
      end
    end
    assert after_rollback_called
  end

  it "supports #rollback_on_exit" do
    @db.transaction do
      @db.rollback_on_exit
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      ROLLBACK
    SQL

    @db.transaction do
      @db.transaction(savepoint: true) do
        @db.rollback_on_exit(savepoint: true)
      end
    end

    assert_logged <<-SQL.strip_heredoc
      BEGIN
      SAVEPOINT active_record_1
      ROLLBACK TO SAVEPOINT active_record_1
      COMMIT
    SQL
  end

  it "doesn't support Database#connect" do
    assert_raises Sequel::ActiveRecordConnection::Error do
      @db.connect
    end
  end
end

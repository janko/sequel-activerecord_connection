require "test_helper"
require "logger"

describe "General extension" do
  before do
    connect_postgresql

    @db.create_table! :records do
      primary_key :id
      String :col
      Time :time
    end
  end

  describe ".connect" do
    it "doesn't test the connection by default" do
      ActiveRecord::Base.establish_connection(**activerecord_config, database: "nonexistent")

      Sequel.connect "#{"jdbc:" if RUBY_ENGINE == "jruby"}postgresql://",
        extensions:     :activerecord_connection,
        keep_reference: false
    end

    it "allows testing the connection" do
      ActiveRecord::Base.establish_connection(**activerecord_config, database: "nonexistent")

      assert_raises ActiveRecord::NoDatabaseError do
        Sequel.connect "#{"jdbc:" if RUBY_ENGINE == "jruby"}postgresql://",
          extensions:     :activerecord_connection,
          keep_reference: false,
          test:           true
      end
    end
  end

  describe "#synchronize" do
    it "returns the underlying connection object" do
      conn = @db.synchronize { |conn| conn }

      if RUBY_ENGINE == "jruby"
        assert_instance_of Java::OrgPostgresqlJdbc::PgConnection, conn
      else
        assert_instance_of PG::Connection, conn
      end
    end

    it "materializes transactions" do
      ActiveRecord::Base.connection.enable_lazy_transactions!

      ActiveRecord::Base.transaction { @db.synchronize {} }

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL
    end if ActiveRecord.version >= Gem::Version.new("6.0")

    it "is re-entrant" do
      @db.synchronize do |conn1|
        @db.synchronize do |conn2|
          assert_equal conn1, conn2
          @db.run "SELECT 1"
        end
      end

      assert_logged <<~SQL
        SELECT 1
      SQL
    end

    it "doesn't allow parallel access for the same connection" do
      ActiveRecord::Base.connection_pool.lock_thread = Thread.current

      q1 = Queue.new
      q2 = Queue.new

      thread1 = Thread.new do
        @db.synchronize do
          q1.pop
        end
      end

      nil until thread1.status == "sleep" # waiting on Queue#pop

      thread2 = Thread.new do
        @db.synchronize do
          q2.push "x"
        end
      end

      nil until thread2.status == "sleep" # waiting on AR lock

      q1.push "x"
      q2.pop

      [thread1, thread2].each(&:join)
    end unless ActiveRecord.version < Gem::Version.new("5.1.0")
  end

  describe "#transaction" do
    it "creates a database transaction" do
      @db.transaction do
        assert_equal 1, ActiveRecord::Base.connection.open_transactions
      end

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL
    end

    it "returns block result" do
      assert_equal :result, @db.transaction { :result }
    end

    it "reuses existing transaction" do
      @db.transaction do
        @db.transaction do
          assert_equal 1, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL

      @db.transaction do
        ActiveRecord::Base.transaction do
          assert_equal 1, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL

      ActiveRecord::Base.transaction do
        @db.transaction do
          assert_equal 1, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL
    end

    it "reuses existing savepoint" do
      @db.transaction do
        @db.transaction(savepoint: true) do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
          @db.transaction do
            assert_equal 2, ActiveRecord::Base.connection.open_transactions
          end
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
          @db.transaction do
            assert_equal 2, ActiveRecord::Base.connection.open_transactions
          end
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL
    end

    it "support :savepoint option" do
      @db.transaction do
        @db.transaction(savepoint: true) do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: :only) do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      @db.transaction(auto_savepoint: true) do
        @db.transaction(savepoint: false) do
          assert_equal 1, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL

      ActiveRecord::Base.transaction(joinable: false) do
        @db.transaction(savepoint: false) do
          assert_equal 1, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        COMMIT
      SQL

      @db.transaction do
        @db.transaction(savepoint: true) do
          raise Sequel::Rollback
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        ROLLBACK TO SAVEPOINT active_record_1
        COMMIT
      SQL
    end

    it "supports :auto_savepoint option" do
      @db.transaction(auto_savepoint: true) do
        @db.transaction do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      @db.transaction(auto_savepoint: true) do
        ActiveRecord::Base.transaction do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      ActiveRecord::Base.transaction(joinable: false) do
        @db.transaction do
          assert_equal 2, ActiveRecord::Base.connection.open_transactions
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        RELEASE SAVEPOINT active_record_1
        COMMIT
      SQL

      @db.transaction(auto_savepoint: true) do
        @db.transaction do
          raise Sequel::Rollback
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        ROLLBACK TO SAVEPOINT active_record_1
        COMMIT
      SQL
    end

    it "supports :rollback option" do
      @db.transaction(rollback: :always) { }

      assert_logged <<~SQL
        BEGIN
        ROLLBACK
      SQL

      assert_raises Sequel::Rollback do
        @db.transaction(rollback: :reraise) do
          raise Sequel::Rollback
        end
      end

      assert_logged <<~SQL
        BEGIN
        ROLLBACK
      SQL
    end

    it "rolls back on exceptions" do
      assert_raises KeyError do
        @db.transaction do
          @db.run "SELECT 1"
          raise KeyError
        end
      end

      assert_logged <<~SQL
        BEGIN
        SELECT 1
        ROLLBACK
      SQL
    end

    it "rolls back on Sequel::Rollback" do
      @db.transaction do
        raise Sequel::Rollback
      end

      assert_logged <<~SQL
        BEGIN
        ROLLBACK
      SQL

      @db.transaction do
        @db.transaction(savepoint: true) do
          raise Sequel::Rollback
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        ROLLBACK TO SAVEPOINT active_record_1
        COMMIT
      SQL
    end

    it "supports :isolation option" do
      @db.transaction(isolation: :uncommitted) { }

      assert_logged <<~SQL
        BEGIN
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
        COMMIT
      SQL

      @db.transaction(isolation: :committed) { }

      assert_logged <<~SQL
        BEGIN
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED
        COMMIT
      SQL

      @db.transaction(isolation: :repeatable) { }

      assert_logged <<~SQL
        BEGIN
        SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
        COMMIT
      SQL

      @db.transaction(isolation: :serializable) { }

      assert_logged <<~SQL
        BEGIN
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
        COMMIT
      SQL
    end
  end

  describe "#in_transaction?" do
    it "returns true inside Sequel transaction" do
      @db.transaction do
        assert_equal true, @db.in_transaction?
        assert_equal true, ActiveRecord::Base.connection.transaction_open?
      end
    end

    it "returns true inside ActiveRecord transaction" do
      ActiveRecord::Base.transaction do
        assert_equal true, @db.in_transaction?
        assert_equal true, ActiveRecord::Base.connection.transaction_open?
      end
    end

    it "returns false when outside transaction" do
      assert_equal false, @db.in_transaction?
    end

    it "returns false when ActiveRecord transaction finished" do
      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) { }
      end
      assert_equal false, @db.in_transaction?
    end
  end

  describe "#after_commit" do
    it "supports transaction hooks" do
      after_commit_called = false
      @db.transaction do
        @db.after_commit { after_commit_called = true }
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_commit { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.after_commit { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      @db.transaction do
        @db.after_commit { after_commit_called = true }
        raise Sequel::Rollback
      end
      refute after_commit_called

      after_commit_called = false
      @db.after_commit { after_commit_called = true }
      assert after_commit_called
    end

    it "supports transaction hooks when Active Record holds the transaction" do
      after_commit_called = false
      ActiveRecord::Base.transaction do
        @db.after_commit { after_commit_called = true }
        refute after_commit_called
      end
      assert after_commit_called

      if ActiveRecord.version >= Gem::Version.new("5.0")
        after_commit_called = false
        ActiveRecord::Base.transaction(joinable: false) do
          @db.transaction do
            @db.after_commit { after_commit_called = true }
            refute after_commit_called
          end
          assert after_commit_called
        end

        after_commit_called = false
        ActiveRecord::Base.transaction(joinable: false) do
          ActiveRecord::Base.transaction do
            @db.after_commit { after_commit_called = true }
            refute after_commit_called
          end
          assert after_commit_called
        end
      end

      after_commit_called = false
      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) do
          @db.after_commit { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.after_commit { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called
    end

    it "supports savepoint hooks" do
      after_commit_called = false
      @db.transaction do
        @db.after_commit(savepoint: true) { after_commit_called = true }
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_commit(savepoint: true) { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_commit(savepoint: true) { after_commit_called = true }
          raise Sequel::Rollback
        end
      end
      refute after_commit_called

      after_commit_called = false
      @db.after_commit(savepoint: true) { after_commit_called = true }
      assert after_commit_called
    end

    it "supports savepoint hooks when Active Record holds the savepoint" do
      after_commit_called = false
      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.after_commit(savepoint: true) { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called

      if ActiveRecord.version >= Gem::Version.new("5.0")
        after_commit_called = false
        @db.transaction(auto_savepoint: true) do
          ActiveRecord::Base.transaction do
            @db.after_commit(savepoint: true) { after_commit_called = true }
            refute after_commit_called
          end
          assert after_commit_called
        end

        after_commit_called = false
        ActiveRecord::Base.transaction(joinable: false) do
          ActiveRecord::Base.transaction do
            @db.after_commit(savepoint: true) { after_commit_called = true }
            refute after_commit_called
          end
          assert after_commit_called
        end
      end

      after_commit_called = false
      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) do
          @db.after_commit(savepoint: true) { after_commit_called = true }
        end
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.transaction(savepoint: true) do
            @db.after_commit(savepoint: true) { after_commit_called = true }
          end
        end
        refute after_commit_called
      end
      assert after_commit_called

      after_commit_called = false
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.transaction(savepoint: true) do
            @db.after_commit(savepoint: true) { after_commit_called = true }
          end
        end
        refute after_commit_called
      end
      assert after_commit_called
    end
  end

  describe "#after_rollback" do
    it "supports transaction hooks" do
      after_rollback_called = false
      @db.transaction do
        @db.after_rollback { after_rollback_called = true }
        refute after_rollback_called
        raise Sequel::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback { after_rollback_called = true }
        end
        refute after_rollback_called
        raise Sequel::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.after_rollback { after_rollback_called = true }
        end
        refute after_rollback_called
        raise Sequel::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      @db.transaction do
        @db.after_rollback { after_rollback_called = true }
      end
      refute after_rollback_called

      after_rollback_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback { after_rollback_called = true }
          raise Sequel::Rollback
        end
      end
      refute after_rollback_called

      after_rollback_called = false
      @db.after_rollback { after_rollback_called = true }
      refute after_rollback_called
    end

    it "supports transaction hooks when Active Record holds the transaction" do
      after_rollback_called = false
      ActiveRecord::Base.transaction do
        @db.after_rollback { after_rollback_called = true }
        refute after_rollback_called
        raise ActiveRecord::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback { after_rollback_called = true }
          refute after_rollback_called
          raise Sequel::Rollback
        end
        assert after_rollback_called
      end

      after_rollback_called = false
      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback { after_rollback_called = true }
        end
        refute after_rollback_called
        raise ActiveRecord::Rollback
      end
      assert after_rollback_called
    end

    it "supports savepoint hooks" do
      after_rollback_called = false
      @db.transaction do
        @db.after_rollback(savepoint: true) { after_rollback_called = true }
        refute after_rollback_called
        raise Sequel::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback(savepoint: true) { after_rollback_called = true }
          raise Sequel::Rollback
        end
        assert after_rollback_called
      end

      after_rollback_called = false
      @db.transaction do
        @db.after_rollback(savepoint: true) { after_rollback_called = true }
      end
      refute after_rollback_called

      after_rollback_called = false
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback(savepoint: true) { after_rollback_called = true }
        end
      end
      refute after_rollback_called

      after_rollback_called = false
      @db.after_rollback(savepoint: true) { after_rollback_called = true }
      refute after_rollback_called
    end

    it "supports savepoint hooks when Active Record holds the savepoint" do
      after_rollback_called = false
      ActiveRecord::Base.transaction do
        @db.after_rollback(savepoint: true) { after_rollback_called = true }
        refute after_rollback_called
        raise ActiveRecord::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.after_rollback(savepoint: true) { after_rollback_called = true }
          refute after_rollback_called
          raise ActiveRecord::Rollback
        end
        assert after_rollback_called
      end

      after_rollback_called = false
      @db.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.after_rollback(savepoint: true) { after_rollback_called = true }
        end
        refute after_rollback_called
        raise Sequel::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      ActiveRecord::Base.transaction do
        @db.transaction(savepoint: true) do
          @db.after_rollback(savepoint: true) { after_rollback_called = true }
        end
        refute after_rollback_called
        raise ActiveRecord::Rollback
      end
      assert after_rollback_called

      after_rollback_called = false
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.transaction(requires_new: true) do
          @db.transaction(savepoint: true) do
            @db.after_rollback(savepoint: true) { after_rollback_called = true }
          end
          refute after_rollback_called
          raise ActiveRecord::Rollback
        end
        assert after_rollback_called
      end
    end
  end

  describe "#rollback_on_exit" do
    it "rolls back on transaction exit" do
      @db.transaction do
        @db.rollback_on_exit
      end

      assert_logged <<~SQL
        BEGIN
        ROLLBACK
      SQL

      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.rollback_on_exit(savepoint: true)
        end
      end

      assert_logged <<~SQL
        BEGIN
        SAVEPOINT active_record_1
        ROLLBACK TO SAVEPOINT active_record_1
        COMMIT
      SQL
    end
  end

  describe "#rollback_checker" do
    it "returns block that returns whether transaction was rolled back" do
      rollback_checker = nil

      @db.transaction do
        rollback_checker = @db.rollback_checker
      end
      assert_equal false, rollback_checker.call

      @db.transaction do
        rollback_checker = @db.rollback_checker
        raise Sequel::Rollback
      end
      assert_equal true, rollback_checker.call
    end
  end

  describe "#timezone" do
    it "defaults to ActiveRecord::Base.default_timezone" do
      ActiveRecord::Base.default_timezone = :utc
      assert_equal :utc, @db.timezone

      ActiveRecord::Base.default_timezone = :local
      assert_equal :local, @db.timezone
    end

    it "picks manually set value" do
      ActiveRecord::Base.default_timezone = :utc
      @db.timezone = :local

      assert_equal :local, @db.timezone
    end
  end

  describe "#log_connection_yield" do
    it "still logs queries to Sequel logger(s)" do
      @db.logger = Logger.new(output = StringIO.new)
      @db.run "SELECT 1"

      assert_match(/SELECT 1/, output.string)
    end
  end

  describe "#valid_connection?" do
    it "returns true if connection is valid" do
      conn = @db.synchronize { |conn| conn }

      assert_equal true, @db.valid_connection?(conn)
    end
  end

  describe "#connect" do
    it "is disallowed" do
      assert_raises Sequel::ActiveRecordConnection::Error do
        @db.connect
      end
    end
  end

  describe "#disconnect" do
    it "doesn't close the connection" do
      conn = @db.synchronize { |conn| conn }
      @db.disconnect
      refute conn.finished?
    end unless RUBY_ENGINE == "jruby"
  end
end

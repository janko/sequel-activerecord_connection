require "test_helper"

describe "postgres connection" do
  before do
    connect_postgresql

    @db.create_table! :records do
      primary_key :id
      String :col
      Time :time
    end
  end

  it "supports Dataset#insert" do
    assert_equal 1, @db[:records].insert(col: "a")
    assert_equal 2, @db[:records].insert(col: "a")
  end

  it "supports Dataset#each" do
    @db[:records].multi_insert [{ col: "a" }, { col: "b" }, { col: "c" }]

    records = @db[:records].order(:id).all

    assert_equal 1,   records[0][:id]
    assert_equal "a", records[0][:col]
    assert_equal 2,   records[1][:id]
    assert_equal "b", records[1][:col]
    assert_equal 3,   records[2][:id]
    assert_equal "c", records[2][:col]

    assert_logged <<~SQL
      INSERT INTO "records" ("col") VALUES ('a'), ('b'), ('c')
      SELECT * FROM "records" ORDER BY "id"
    SQL
  end

  it "handles empty dataset" do
    assert_equal [], @db[:records].all
    assert_equal [:id, :col, :time], @db[:records].columns
  end

  it "supports Database#update" do
    @db[:records].multi_insert [{ col: "a" }, { col: "b" }]

    assert_equal 0, @db[:records].where(col: "c").update(col: "x")
    assert_equal 1, @db[:records].where(col: "a").update(col: "y")
    assert_equal 2, @db[:records].update(col: "z")

    records = @db[:records].order(:id).all

    assert_equal 1,   records[0][:id]
    assert_equal "z", records[0][:col]
    assert_equal 2,   records[1][:id]
    assert_equal "z", records[1][:col]

    assert_logged <<~SQL
      UPDATE "records" SET "col" = 'x' WHERE ("col" = 'c')
      UPDATE "records" SET "col" = 'y' WHERE ("col" = 'a')
      UPDATE "records" SET "col" = 'z'
    SQL
  end

  it "supports Database#get" do
    assert_instance_of Time, @db.get(Sequel::CURRENT_TIMESTAMP)
    assert_equal 1,          @db.get(1)
    assert_equal "foo",      @db.get("foo")

    assert_logged <<~SQL
      SELECT CURRENT_TIMESTAMP AS "v" LIMIT 1
      SELECT 1 AS "v" LIMIT 1
      SELECT 'foo' AS "v" LIMIT 1
    SQL
  end

  it "supports bound variables" do
    record_id = @db[:records].insert(col: "foo")

    record = @db[:records]
      .where(col: :$c)
      .call(:first, c: "foo")

    assert_equal record_id, record[:id]

    if RUBY_ENGINE == "jruby"
      assert_logged <<~SQL
        PREPARE SELECT * FROM "records" WHERE ("col" = ?) LIMIT 1
        EXECUTE; ["foo"]
      SQL
    else
      assert_logged <<~SQL
        SELECT * FROM "records" WHERE ("col" = $1) LIMIT 1; ["foo"]
      SQL
    end
  end

  it "supports prepared statements" do
    record_id = @db[:records].insert(col: "foo")

    record = @db[:records]
      .where(col: :$c)
      .prepare(:first, :first_by_col)
      .call(c: "foo")

    assert_equal record_id, record[:id]

    if RUBY_ENGINE == "jruby"
      assert_logged <<~SQL
        PREPARE first_by_col: SELECT * FROM "records" WHERE ("col" = ?) LIMIT 1
        EXECUTE first_by_col; ["foo"]
      SQL
    else
      assert_logged <<~SQL
        PREPARE first_by_col AS SELECT * FROM "records" WHERE ("col" = $1) LIMIT 1
        EXECUTE first_by_col; ["foo"]
      SQL
    end
  end

  it "raises Sequel exceptions" do
    assert_raises Sequel::UniqueConstraintViolation do
      @db[:records].multi_insert [{ id: 1 }, { id: 1 }]
    end

    @db.alter_table(:records) { add_foreign_key :fkey, :records }

    assert_raises Sequel::ForeignKeyConstraintViolation do
      @db[:records].insert(fkey: 50)
    end

    @db.alter_table(:records) { add_column :required, :text, null: false, default: "default" }

    assert_raises Sequel::NotNullConstraintViolation do
      @db[:records].insert(required: nil)
    end
  end

  it "converts other exceptions" do
    assert_raises Sequel::DatabaseError do
      @db[:foo].all
    end
  end

  it "correctly handles ActiveRecord's default UTC timezone setting" do
    time = Time.new(2020, 4, 26, 0, 0, 0, "+02:00")

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO "records" ("time") VALUES ('2020-04-25 22:00:00.000000+0000') RETURNING "id"
    SQL
  end

  it "correctly handles ActiveRecord's local timezone setting" do
    set_activerecord_timezone(:local)

    time = Time.new(2020, 4, 26, 0, 0, 0)
    utc_offset = time.to_s[/\S+$/]

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO "records" ("time") VALUES ('2020-04-26 00:00:00.000000#{utc_offset}') RETURNING "id"
    SQL
  end

  next if RUBY_ENGINE == "jruby"

  it "raises exception on unsupported transaction options" do
    assert_raises(Sequel::ActiveRecordConnection::Error) do
      @db.transaction(deferrable: true) { }
    end
    assert_raises(Sequel::ActiveRecordConnection::Error) do
      @db.transaction(read_only: true) { }
    end
    assert_raises(Sequel::ActiveRecordConnection::Error) do
      @db.transaction(synchronous: true) { }
    end
  end

  it "supports #copy_table and #copy_into" do
    @db.copy_into(:records, format: "csv", data: ["1,foo,2021-01-10 T00:00:00"])

    assert_logged <<~SQL
      COPY "records" FROM STDIN (FORMAT csv)
    SQL

    assert_equal Hash[id: 1, col: "foo", time: Time.utc(2021, 1, 10)], @db[:records].first

    assert_equal "1,foo,2021-01-10 00:00:00", @db.copy_table(:records, format: "csv").chomp

    assert_logged <<~SQL
      COPY "records" TO STDOUT (FORMAT csv)
    SQL
  end

  it "converts disconnects into Sequel::DatabaseDisconnectError" do
    @db.synchronize do |conn|
      @db.disconnect_connection(conn)
      assert_raises Sequel::DatabaseDisconnectError do
        @db.copy_table(@db[:records])
      end
    end
  end

  it "clears Active Record statement cache on ActiveRecord::PreparedStatementCacheExpired" do
    statement_cache = ActiveRecord::Base.connection_pool.with_connection { |connection| connection.instance_variable_get(:@statements) }

    model = Class.new(ActiveRecord::Base)
    model.table_name = :records
    model.find(@db[:records].insert({ col: "foo" }))

    assert_equal 1, statement_cache.length

    assert_raises ActiveRecord::PreparedStatementCacheExpired do
      @db.transaction { raise ActiveRecord::PreparedStatementCacheExpired }
    end

    assert_equal 0, statement_cache.length
  end if defined?(ActiveRecord::PreparedStatementCacheExpired)

  it "supports pg_streaming database extension from sequel_pg" do
    @db.extension :pg_streaming
    @db[:records].multi_insert [{ col: "a" }, { col: "b" }]
    records = @db[:records].order(:col).stream.enum_for(:each).to_a
    assert_equal ["a", "b"], records.map { |r| r[:col] }
  end

  it "supports pg_auto_parameterize extension" do
    @db.extension :pg_auto_parameterize
    @db[:records].where(col: "a").to_a
    assert_logged <<~SQL
      SELECT * FROM "records" WHERE ("col" = $1); ["a"]
    SQL
  end

  it "reverts type maps inside a Sequel transaction" do
    @db.transaction do |conn|
      rows = ActiveRecord::Base.connection_pool.with_connection { |connection| connection.exec_query("SELECT TRUE") }

      assert_equal true, rows[0].values.first
    end
  end if ActiveRecord.version >= Gem::Version.new("5.0")

  it "patches type maps for normal statements" do
    assert_equal true, @db.schema(:records)[0][1][:primary_key]
  end

  it "patches type maps for prepared statements" do
    rows = @db["SELECT TRUE"].prepare(:select, :select_true).call
    assert_equal true, rows[0].values.first
  end

  it "clears Active Records query cache" do
    ActiveRecord::Base.connection_pool.with_connection(&:enable_query_cache!)

    activerecord_model = Class.new(ActiveRecord::Base)
    activerecord_model.table_name = :records

    assert_nil activerecord_model.find_by(col: "foo")
    @db[:records].disable_insert_returning.insert(col: "foo")
    refute_nil activerecord_model.find_by(col: "foo")

    assert_nil activerecord_model.find_by(col: "bar")
    @db[:records].returning(:id).insert(col: "bar")
    refute_nil activerecord_model.find_by(col: "bar")
  end
end

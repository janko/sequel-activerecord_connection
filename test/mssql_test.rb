require "test_helper"
require "active_support/core_ext/kernel/reporting"

describe "mssql connection" do
  before do
    connect_sqlserver

    @db.create_table! :records do
      primary_key :id
      String :col, unique: true
      Time :time
    end
  end

  it "supports Dataset#insert" do
    assert_equal 1, @db[:records].insert(col: "a")
    assert_equal 2, @db[:records].insert(col: "b")
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
      BEGIN TRANSACTION
      INSERT INTO [RECORDS] ([COL]) VALUES (N'a'), (N'b'), (N'c')
      COMMIT TRANSACTION
      SELECT * FROM [RECORDS] ORDER BY [ID]
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
    assert_equal 2, @db[:records].update(time: Sequel::CURRENT_TIMESTAMP)

    records = @db[:records].order(:id).all

    assert_equal 1,   records[0][:id]
    assert_equal "y", records[0][:col]
    assert_equal 2,   records[1][:id]
    assert_instance_of Time, records[1][:time]

    assert_logged <<~SQL
      UPDATE [RECORDS] SET [COL] = N'x' WHERE ([COL] = N'c')
      UPDATE [RECORDS] SET [COL] = N'y' WHERE ([COL] = N'a')
      UPDATE [RECORDS] SET [TIME] = CURRENT_TIMESTAMP
    SQL
  end

  it "supports Database#get" do
    assert_instance_of Time, @db.get(Sequel::CURRENT_TIMESTAMP)
    assert_equal 1,          @db.get(1)
    assert_equal "foo",      @db.get("foo")

    assert_logged <<~SQL
      SELECT TOP (1) CURRENT_TIMESTAMP AS [V]
      SELECT TOP (1) 1 AS [V]
      SELECT TOP (1) N'foo' AS [V]
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
        EXEC sp_executesql N'SELECT TOP (1) * FROM [RECORDS] WHERE ([COL] = @c)', N'@c nvarchar(max)', @c = N'foo'
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
        EXEC sp_executesql N'SELECT TOP (1) * FROM [RECORDS] WHERE ([COL] = @c)', N'@c nvarchar(max)', @c = N'foo'
      SQL
    end
  end

  it "raises Sequel exceptions" do
    assert_raises Sequel::UniqueConstraintViolation do
      @db[:records].multi_insert [{ col: "a" }, { col: "a" }]
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
      INSERT INTO [RECORDS] ([TIME]) VALUES ('2020-04-25T22:00:00.000')
    SQL
  end

  it "correctly handles ActiveRecord's local timezone setting" do
    set_activerecord_timezone(:local)

    time = Time.new(2020, 4, 26, 0, 0, 0)

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO [RECORDS] ([TIME]) VALUES ('2020-04-26T00:00:00.000')
    SQL
  end
end unless Gem::Specification.find_all_by_name("activerecord-sqlserver-adapter").empty?

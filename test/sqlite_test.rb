require "test_helper"

describe "sqlite3 connection" do
  before do
    connect_sqlite3

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

    assert_equal [:id, :col, :time], @db[:records].columns

    assert_logged <<-SQL.strip_heredoc
      #{RUBY_ENGINE == "jruby" ? "BEGIN TRANSACTION" : "begin transaction"}
      INSERT INTO `records` (`col`) VALUES ('a'), ('b'), ('c')
      #{RUBY_ENGINE == "jruby" ? "COMMIT TRANSACTION" : "commit transaction"}
      SELECT * FROM `records` ORDER BY `id`
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

    assert_logged <<-SQL.strip_heredoc
      UPDATE `records` SET `col` = 'x' WHERE (`col` = 'c')
      UPDATE `records` SET `col` = 'y' WHERE (`col` = 'a')
      UPDATE `records` SET `col` = 'z'
    SQL
  end

  it "supports Database#get" do
    assert_equal 1,     @db.get(1)
    assert_equal "foo", @db.get("foo")

    assert_logged <<-SQL.strip_heredoc
      SELECT 1 AS 'v' LIMIT 1
      SELECT 'foo' AS 'v' LIMIT 1
    SQL
  end

  it "supports bound variables" do
    record_id = @db[:records].insert(col: "foo")

    record = @db[:records]
      .where(col: :$c)
      .call(:first, c: "foo")

    assert_equal record_id, record[:id]
  end

  it "supports prepared statements" do
    record_id = @db[:records].insert(col: "foo")

    record = @db[:records]
      .where(col: :$c)
      .prepare(:first, :first_by_col)
      .call(c: "foo")

    assert_equal record_id, record[:id]
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

  it "correctly handles ActiveRecord's default UTC timezone setting" do
    time = Time.new(2020, 4, 26, 0, 0, 0, "+02:00")

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<-SQL.strip_heredoc
      INSERT INTO `records` (`time`) VALUES ('2020-04-25 22:00:00.000000')
    SQL
  end

  it "adds CURRENT_* timestamp in UTC when that's ActiveRecord's timezone" do
    @db.extension :date_arithmetic
    @db[:records].insert(time: Time.now)

    refute_empty @db[:records].where(Sequel[:time] < Sequel.date_add(Sequel::CURRENT_TIMESTAMP, minutes: 1))
    refute_empty @db[:records].where(Sequel[:time] > Sequel.date_sub(Sequel::CURRENT_TIMESTAMP, minutes: 1))
  end if Sequel::MAJOR >= 5 && Sequel::MINOR >= 33

  it "correctly handles ActiveRecord's local timezone setting" do
    ActiveRecord::Base.default_timezone = :local
    @db.timezone = :local

    time = Time.new(2020, 4, 26, 0, 0, 0)

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<-SQL.strip_heredoc
      INSERT INTO `records` (`time`) VALUES ('2020-04-26 00:00:00.000000')
    SQL
  end
end

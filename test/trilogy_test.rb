require "test_helper"

describe "trilogy connection" do
  before do
    connect_trilogy

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

    assert_logged <<~SQL
      INSERT INTO `records` (`col`) VALUES ('a'), ('b'), ('c')
      SELECT version()
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

    assert_logged <<~SQL
      UPDATE `records` SET `col` = 'x' WHERE (`col` = 'c')
      UPDATE `records` SET `col` = 'y' WHERE (`col` = 'a')
      UPDATE `records` SET `col` = 'z'
    SQL
  end

  it "supports Database#get" do
    assert_instance_of Time, @db.get(Sequel::CURRENT_TIMESTAMP)
    assert_equal 1,          @db.get(1)
    assert_equal "foo",      @db.get("foo")

    assert_logged <<~SQL
      SELECT CURRENT_TIMESTAMP AS `v` LIMIT 1
      SELECT 1 AS `v` LIMIT 1
      SELECT 'foo' AS `v` LIMIT 1
    SQL
  end

  it "raises Sequel exceptions" do
    assert_raises Sequel::UniqueConstraintViolation do
      @db[:records].multi_insert [{ id: 1 }, { id: 1 }]
    end

    @db.alter_table(:records) { add_foreign_key :fkey, :records }

    assert_raises Sequel::ForeignKeyConstraintViolation do
      @db[:records].insert(fkey: 50)
    end

    @db.alter_table(:records) { add_column :required, :text, null: false }

    assert_raises Sequel::NotNullConstraintViolation do
      @db[:records].insert(required: nil)
    end
  end

  it "correctly handles ActiveRecord's default UTC timezone setting" do
    time = Time.new(2020, 4, 26, 0, 0, 0, "+02:00")

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO `records` (`time`) VALUES ('2020-04-25 22:00:00')
    SQL
  end

  it "correctly handles ActiveRecord's local timezone setting" do
    set_activerecord_timezone(:local)

    time = Time.new(2020, 4, 26, 0, 0, 0)

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO `records` (`time`) VALUES ('2020-04-26 00:00:00')
    SQL
  end

  it "allows calling Active Record queries inside transaction" do
    activerecord_model = Class.new(ActiveRecord::Base)
    activerecord_model.table_name = :records

    @db.transaction do
      record = activerecord_model.create(col: "foo", time: Time.new(2021, 1, 10))
      record = activerecord_model.find(record.id)

      assert_equal "foo",                 record.col
      assert_equal Time.new(2021, 1, 10), record.time
    end
  end
end unless ActiveRecord.version < Gem::Version.new("7.1") || RUBY_ENGINE == "jruby"

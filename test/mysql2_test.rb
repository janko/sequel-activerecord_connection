require "test_helper"

describe "Mysql2 adapter" do
  before do
    connect("mysql2")
    ActiveRecord::Base.default_timezone = :utc
  end

  after do
    disconnect("mysql2")
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
      BEGIN
      INSERT INTO `records` (`col`) VALUES ('a'), ('b'), ('c')
      COMMIT
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

  it "converts ActiveRecord::RecordNotUnique into Sequel::UniqueConstraintViolation" do
    assert_raises Sequel::UniqueConstraintViolation do
      @db[:records].multi_insert [{ id: 1 }, { id: 1 }]
    end
  end

  it "correctly handles ActiveRecord's UTC timezone setting" do
    ActiveRecord::Base.default_timezone = :utc

    time = Time.new(2020, 4, 26)

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO `records` (`time`) VALUES ('2020-04-25 22:00:00')
    SQL
  end

  it "correctly handles ActiveRecord's local timezone setting" do
    ActiveRecord::Base.default_timezone = :local

    time = Time.new(2020, 4, 26)

    @db[:records].insert(time: time)

    assert_equal time, @db[:records].first[:time]

    assert_logged <<~SQL
      INSERT INTO `records` (`time`) VALUES ('2020-04-26 00:00:00')
    SQL
  end
end

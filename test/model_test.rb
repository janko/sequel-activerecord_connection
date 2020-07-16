require "test_helper"

describe "Don't breake Sequel::Model interface" do
  before do
    connect_postgresql

    @db.create_table! :test_models do
      primary_key :id
      String :col
    end

    Sequel::Model.db = @db
    class TestModel < Sequel::Model
      set_primary_key :id
    end
  end

  after do
    Object.send(:remove_const, :TestModel)
  end

  it ".create returns model" do
    record = TestModel.create
    assert_equal record.is_a?(TestModel), true
  end

  it "#update returns model" do
    record = TestModel.create
    updated_record = record.update(col: "value")
    assert_equal updated_record.is_a?(TestModel), true
  end

  it "#save_changes executes successfully" do
    record = TestModel.create
    record.col = "value"
    record.save_changes
  end
end

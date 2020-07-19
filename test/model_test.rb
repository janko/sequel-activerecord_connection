require "test_helper"

describe "Model integration" do
  before do
    connect_postgresql

    @db.create_table! :records do
      primary_key :id
      String :col
    end

    @model = Class.new(Sequel::Model)
    @model.set_dataset(:records)
  end

  it ".create returns model" do
    assert_instance_of @model, @model.create
  end

  it "#update returns model" do
    assert_instance_of @model, @model.new.update(col: "value")
  end

  it "#save_changes executes successfully" do
    @model.new(col: "value").save_changes
  end
end

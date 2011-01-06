require 'spec_helper'

describe AgentGroup do
  before(:each) do
    @valid_attributes = {
      :user_id => 1,
      :group_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    AgentGroup.create!(@valid_attributes)
  end
end

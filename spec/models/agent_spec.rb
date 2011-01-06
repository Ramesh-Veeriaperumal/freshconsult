require 'spec_helper'

describe Agent do
  before(:each) do
    @valid_attributes = {
      :user_id => 1,
      :signature => "value for signature"
    }
  end

  it "should create a new instance given valid attributes" do
    Agent.create!(@valid_attributes)
  end
end

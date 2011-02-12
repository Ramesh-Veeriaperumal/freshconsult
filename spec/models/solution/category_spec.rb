require 'spec_helper'

describe Solution::Category do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Solution::Category.create!(@valid_attributes)
  end
end

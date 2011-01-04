require 'spec_helper'

describe VARule do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :match_type => "value for match_type",
      :filter_data => "value for filter_data",
      :action_data => "value for action_data"
    }
  end

  it "should create a new instance given valid attributes" do
    VARule.create!(@valid_attributes)
  end
end

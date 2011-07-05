require 'spec_helper'

describe Helpdesk::PicklistValue do
  before(:each) do
    @valid_attributes = {
      :pickable_id => 1,
      :pickable_type => "value for pickable_type",
      :position => 1,
      :value => "value for value"
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::PicklistValue.create!(@valid_attributes)
  end
end

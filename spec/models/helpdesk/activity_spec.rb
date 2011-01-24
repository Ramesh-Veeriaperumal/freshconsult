require 'spec_helper'

describe Helpdesk::Activity do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :description => "value for description",
      :notable_id => 1,
      :notable_type => "value for notable_type"
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::Activity.create!(@valid_attributes)
  end
end

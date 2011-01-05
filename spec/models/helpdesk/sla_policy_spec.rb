require 'spec_helper'

describe Helpdesk::SlaPolicy do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::SlaPolicy.create!(@valid_attributes)
  end
end

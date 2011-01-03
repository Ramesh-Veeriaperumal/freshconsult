require 'spec_helper'

describe Helpdesk::SupportPlan do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :account_id => 1,
      :email => false,
      :phone => false,
      :community => false,
      :twitter => false,
      :facebook => false
    }
  end

  it "should create a new instance given valid attributes" do
    Helpdesk::SupportPlan.create!(@valid_attributes)
  end
end

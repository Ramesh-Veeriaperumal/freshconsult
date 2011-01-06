require 'spec_helper'

describe Group do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :account_id => 1,
      :email_on_assign => false,
      :escalate_to => 1,
      :assign_time => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Group.create!(@valid_attributes)
  end
end

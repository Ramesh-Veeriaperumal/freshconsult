require 'spec_helper'

describe EmailNotification do
  before(:each) do
    @valid_attributes = {
      :type => 1,
      :account_id => 1,
      :requester_notification => false,
      :requester_template => "value for requester_template",
      :agent_notification => false,
      :agent_template => "value for agent_template"
    }
  end

  it "should create a new instance given valid attributes" do
    EmailNotification.create!(@valid_attributes)
  end
end

require 'spec_helper'

describe EmailConfig do
  before(:each) do
    @valid_attributes = {
      :account_id => 1,
      :to_email => "value for to_email",
      :reply_email => "value for reply_email",
      :group_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    EmailConfig.create!(@valid_attributes)
  end
end

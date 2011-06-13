require 'spec_helper'

describe Admin::CannedResponse do
  before(:each) do
    @valid_attributes = {
      :title => "value for title",
      :content => "value for content",
      :user_id => 1,
      :visibility => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Admin::CannedResponse.create!(@valid_attributes)
  end
end

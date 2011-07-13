require 'spec_helper'

describe Admin::TwitterHandle do
  before(:each) do
    @valid_attributes = {
      :twitter_handle => "value for twitter_handle",
      :access_token => "value for access_token",
      :access_secret => "value for access_secret",
      :capture_dm_as_ticket => false,
      :capture_mention_as_ticket => false,
      :primary => false,
      :group_id => 1,
      :product_id => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Admin::TwitterHandle.create!(@valid_attributes)
  end
end

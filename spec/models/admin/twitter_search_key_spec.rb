require 'spec_helper'

describe Admin::TwitterSearchKey do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :search_query => "value for search_query",
      :twitter_handle_id => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Admin::TwitterSearchKey.create!(@valid_attributes)
  end
end

require 'spec_helper'

describe Solution::Article do
  before(:each) do
    @valid_attributes = {
      :title => "value for title",
      :description => "value for description",
      :user_id => 1,
      :folder_id => 1,
      :status => 1,
      :art_type => 1,
      :is_public => false
    }
  end

  it "should create a new instance given valid attributes" do
    Solution::Article.create!(@valid_attributes)
  end
end

require 'spec_helper'

describe ForumCategory do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :product_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    ForumCategory.create!(@valid_attributes)
  end
end

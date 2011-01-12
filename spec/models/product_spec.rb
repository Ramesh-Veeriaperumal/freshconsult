require 'spec_helper'

describe Product do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :to_email => "value for to_email",
      :reply_email => "value for reply_email",
      :solution_category_id => 1,
      :forum_category_id => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Product.create!(@valid_attributes)
  end
end

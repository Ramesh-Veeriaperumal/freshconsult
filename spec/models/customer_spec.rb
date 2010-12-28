require 'spec_helper'

describe Customer do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :cust_identifier => "value for cust_identifier",
      :owner_id => 1,
      :account_id => 1,
      :cust_type => 1,
      :phone => "value for phone",
      :address => "value for address",
      :website => "value for website",
      :description => "value for description"
    }
  end

  it "should create a new instance given valid attributes" do
    Customer.create!(@valid_attributes)
  end
end

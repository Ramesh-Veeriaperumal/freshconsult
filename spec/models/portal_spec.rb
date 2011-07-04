require 'spec_helper'

describe Portal do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :portal_url => "value for portal_url",
      :preferences => "value for preferences",
      :product_id => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Portal.create!(@valid_attributes)
  end
end

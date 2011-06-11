require 'spec_helper'

describe Admin::UserAccess do
  before(:each) do
    @valid_attributes = {
      :accessible_type => "value for accessible_type",
      :accessible_type_id => 1,
      :user_id => 1,
      :visibility => 1,
      :group_id => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Admin::UserAccess.create!(@valid_attributes)
  end
end

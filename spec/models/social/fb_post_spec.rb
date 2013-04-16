require 'spec_helper'

describe Social::FbPost do
  before(:each) do
    @valid_attributes = {
      :post_id => 1,
      :postable_id => 1,
      :postable_type => "value for postable_type"
    }
  end

  it "should create a new instance given valid attributes" do
    Social::FbPost.create!(@valid_attributes)
  end
end

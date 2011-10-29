require 'spec_helper'

describe Social::FacebookPage do
  before(:each) do
    @valid_attributes = {
      :profile_id => 1,
      :access_token => "value for access_token",
      :page_id => 1,
      :page_name => "value for page_name",
      :page_token => "value for page_token",
      :page_img_url => "value for page_img_url",
      :page_link => "value for page_link",
      :import_visitor_posts => false,
      :import_company_posts => false,
      :product_id => 1,
      :account_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Social::FacebookPage.create!(@valid_attributes)
  end
end

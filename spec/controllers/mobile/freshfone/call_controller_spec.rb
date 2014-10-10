require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
load 'spec/support/freshfone_call_spec_helper.rb'
RSpec.configure do |c|
  c.include FreshfoneCallSpecHelper
end


RSpec.describe Freshfone::CallController do
  before(:all) do
    create_test_freshfone_account
    create_freshfone_user
  end

  before(:each) do
    api_login
  end

  it "should get caller details" do
    setup_caller_data
    get :caller_data, { :PhoneNumber => @caller_number, :format => "json" }
    json_response.should include("user_name","call_meta")
    json_response["call_meta"].should include("number","group")
  end
end
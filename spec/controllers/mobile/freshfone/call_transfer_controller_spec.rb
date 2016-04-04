require 'spec_helper'
load 'spec/support/freshfone_transfer_spec_helper.rb'
RSpec.configure do |c|
  c.include FreshfoneTransferSpecHelper
end

RSpec.describe Freshfone::CallTransferController do
  self.use_transactional_fixtures = false

  before(:each) do
  	api_login
    create_test_freshfone_account
  end

  it "should get available agents list" do
    create_dummy_freshfone_users
  	get :available_agents, { :format => "json" }
  	json_response.each do |result|
      result.should include("available_agents_name","id")
    end
  end
end
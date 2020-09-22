require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
load 'spec/support/freshfone_call_spec_helper.rb'

RSpec.configure do |c|
  c.include FreshfoneCallSpecHelper
end

RSpec.describe Freshfone::UsersController do
  self.use_transactional_fixtures = false

  context "when mobile request" do
    before(:each) do
      api_login
      create_test_freshfone_account
      create_freshfone_user
    end

    it "should get refresh token when feature enabled" do
      Freshfone::User.any_instance.stubs(:incoming_preference).returns(1)
      post :refresh_token , { :format => "json", :status => 1 }
      json_response.should include("token","update_status","client","expire")
      freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
      freshfone_user.should be_online
      freshfone_user.mobile_token_refreshed_at.should be > 1.hours.ago
    end

    it "should NOT get refresh token when feature is disabled" do
      @account.features.freshfone.destroy
      post :refresh_token, { :format => "json" }
      json_response.should include("requires_feature")
      json_response["requires_feature"].should be false
      json_response.should_not include("token","update_status","client","expire")
      @account.features.freshfone.create
      @account.reload
    end

    it "should post presence of an user" do
      post :presence , { :format => "json" }
      json_response.should include("update_status")
      json_response["update_status"].should be true
    end

    it "should send incoming call" do
      freshfone_call = create_freshfone_call
      post :in_call, {:format => "json", :From => "+16617480240", :To => "+12407433321", :CallSid => freshfone_call.call_sid, :outgoing => "false"}
      json_response.should include("update_status","call_sid")
      json_response["update_status"].should be true
    end

    it "should send outgoing call to server" do
      post :in_call, { :format => "json", :outgoing => "true" }
      json_response.should include("update_status","call_sid")
      json_response["call_sid"].should be_eql("CA2db76c748cb6f081853f80dace462a04")
    end
  end


  context "when web request" do
    setup :activate_authlogic
    
    # When web request, it should reset the mobile_token_refreshed_at to 2 hours before
    # current time.
    it "should update mobile_token_refreshed_at to 2 Hours ago when web request" do
      request.env["HTTP_ACCEPT"] = "application/json"
      log_in(@agent)
      create_test_freshfone_account
      create_freshfone_user
      Freshfone::User.any_instance.stubs(:incoming_preference).returns(0)
      controller.stubs(:bridge_queued_call)
      post :refresh_token , { :status => 0 }
      freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
      freshfone_user.mobile_token_refreshed_at.should be < 1.hours.ago
    end
  end
end
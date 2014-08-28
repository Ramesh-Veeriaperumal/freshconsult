require 'spec_helper'

describe HomeController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	it "should redirected to support home page unless it is a privileged_user" do
		get :index
		response.should redirect_to "/support/home"
	end

	it "should redirected to helpdesk_dashboard page" do
		login_admin
		get :index
		response.should redirect_to "/helpdesk"
	end
end
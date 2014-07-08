require 'spec_helper'

describe HomeController do
	integrate_views
    setup :activate_authlogic
    self.use_transactional_fixtures = false

    it "should redirected to support home page unless it is a privileged_user" do
    	get :index
    	response.redirected_to.should eql "/support/home"
    end

	it "should redirected to helpdesk_dashboard page" do
	  	login_admin
	  	get :index
	  	response.redirected_to.should eql "/helpdesk"
	end
end
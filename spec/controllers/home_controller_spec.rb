require 'spec_helper'

describe HomeController do
  
  describe "GET 'index'" do
    it "should redirect to end user portal" do
      get 'index'
      response.should redirect_to(support_guides_path)
    end
    
    it "should redirect to helpdesk dashboard for administrators" do
      build_user(:admin)
      get 'index'
      response.should redirect_to(helpdesk_dashboard_path)
    end
    
    it "should redirect to portal for end users" do
      build_user(:end_user)
      get 'index'
      response.should redirect_to(support_guides_path)
    end

    it "should redirect to dashboard for agents" do
      build_user(:agent)
      get 'index'
      response.should redirect_to(helpdesk_dashboard_path)
    end

  end
end

def build_user(user_role)
  activate_authlogic
  user = Factory.build(user_role)
  user.active = true
  UserSession.create! user
end

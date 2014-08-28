require 'spec_helper'

describe Admin::PortalController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should display Customize poratl page" do
    get :index
    response.body.should =~ /Customize your Public Customer Portal/
    response.should be_success
  end

  it "should update" do
    RSpec.configuration.account.sso_enabled = false
    RSpec.configuration.account.save(:validate => false)

    put :update, { 
      :id => RSpec.configuration.account.id,
      :account => { 
        :features => {
          :anonymous_tickets => "0", 
          :open_solutions    => "1", 
          :auto_suggest_solutions => "0", 
          :open_forums=>"1",
          :google_signin=>"1", 
          :facebook_signin=>"0", 
          :twitter_signin=>"0", 
          :signup_link=>"1", 
          :captcha=>"1",
          :hide_portal_forums=>"0"
        }
      }
    }
    available_feature = ["OpenSolutionsFeature","OpenForumsFeature","GoogleSigninFeature","SignupLinkFeature","CaptchaFeature"]
    available_feature.each do |feature|
      RSpec.configuration.account.features.find_by_type("#{feature}").should_not be_nil
    end

    restricted_feature = ["AnonymousTicketsFeature","AutoSuggestSolutionsFeature","FacebookSigninFeature","TwitterSigninFeature",
                          "HidePortalForumsFeature"]
    restricted_feature.each do |feature|
      RSpec.configuration.account.features.find_by_type("#{feature}").should be_nil
    end
  end
end
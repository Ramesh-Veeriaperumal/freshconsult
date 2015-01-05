require 'spec_helper'

describe Admin::PortalController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should display Customize poratl page" do
    get :index
    response.body.should =~ /Customer Portal Configuration/
    response.should be_success
  end

  it "should update" do
    @account.sso_enabled = false
    @account.save(false)
    agent_ids = []
    3.times do
      agent_ids << add_test_agent(@account).id
    end

    put :update, { 
      :id => @account.id,
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
          :hide_portal_forums=>"0",
          :moderate_all_posts=>"1",
          :moderate_posts_with_links=>"0"
        }
      },
      :forum_moderators => agent_ids
    }
    @account.reload
    available_feature = ["OpenSolutionsFeature","OpenForumsFeature","GoogleSigninFeature","SignupLinkFeature","CaptchaFeature",
                        "ModerateAllPostsFeature"]
    available_feature.each do |feature|
      @account.features.find_by_type("#{feature}").should_not be_nil
    end

    restricted_feature = ["AnonymousTicketsFeature","AutoSuggestSolutionsFeature","FacebookSigninFeature","TwitterSigninFeature",
                          "HidePortalForumsFeature"]
    restricted_feature.each do |feature|
      @account.features.find_by_type("#{feature}").should be_nil
    end
    @account.forum_moderators.map(&:moderator_id).should =~ agent_ids
  end
end
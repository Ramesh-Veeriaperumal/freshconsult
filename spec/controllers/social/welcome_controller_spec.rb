require 'spec_helper'


describe Social::WelcomeController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    Resque.inline = true
    #@account = create_test_account
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response)
    end
    Social::TwitterHandle.destroy_all
    @account.account_additional_settings.update_attributes(:additional_settings => nil)
    Resque.inline = false
  end

  before(:each) do
    login_admin
  end
  
  it "should fetch all the streams(default/custom) on rendering the page if there are no handles associated" do
    get :index
    response.should render_template("social/welcome/index")
  end
  
  it "should get the response rate of a particular handle" do
    OAuth2::AccessToken.any_instance.stubs(:get).returns(sample_tweets_array, sample_tweets_array(false))
    request.env["HTTP_ACCEPT"] = "application/javascript"
    get :get_stats, {
      :twitter_handle => "TestingGnip"
    }
    response.should render_template("social/welcome/get_stats")
    assigns[:perct].should eql(12)
  end
  
  it "should set enable feature to false if TURN OFF SOCIAL is clicked and redirect to admin home" do
    post :enable_feature, {
      :twitter => "false"
    }
    @account.reload
    @account.account_additional_settings.additional_settings[:enable_social].should eql(false)
    response.should redirect_to admin_home_index_url
  end

end

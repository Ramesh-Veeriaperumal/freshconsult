require 'spec_helper'

describe AuthorizationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @user = add_test_agent(@account)
    @new_installed_application = FactoryGirl.build(:installed_application, 
                                                {
                                                  :application_id => 19,
                                                  :account_id => @account.id, 
                                                  :configs => { :inputs => {}}
                                                })
    @new_installed_application.save!
    @auth_data = FactoryGirl.build(:authorization, {:provider => "facebook",
                    :uid => "int_uid", :user_id => @user.id, :account_id => @account.id })
    @data = @auth_data.save!
  end

  it "should create authorization for google calendar" do
    @request.env["omniauth.origin"] = "id=#{@account.id}&app_name=google_calendar&user_id=1"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      { :credentials => { :expires => true,
                          :expires_at => "1429609241",
                          :refresh_token => "1/tNVnf_juKFRDSygGBGtCz0vyEXKz1JwKhID_AgD8LMs",
                          "token" => "ya29.XAH7EFHaE5nCOBXDQmiJxYRpQf3Ss-hTsnLSStXiQ7jrPdiyDIDA3gryYF8yDo1gpcU1SjHr-Omq8g"
                        }, 
        :extra => { :raw_info => { :email => "bala@freshdesk.com",
                                   :family_name=>"Kumar", 
                                   :gender=>"male", 
                                   :given_name=>"Bala", 
                                   :hd=>"freshdesk.com", 
                                   :id=>"116155779926622689580",
                                   :link=>"https://plus.google.com/+BalaKumarSM", 
                                   :locale=>"en", 
                                   :name=>"Bala Kumar", 
                                   :picture=>"https://lh5.googleusercontent.com/-o3nQbAwnMXs/AAAAAAAAAAI/AAAAAAAAABc/yXa8EfpQ6K8/photo.jpg", 
                                   :verified_email=>true
                                  }
                  },
        :info => { :email=>"bala@freshdesk.com", 
                   :first_name=>"Bala", 
                   :image=>"https://lh5.googleusercontent.com/-o3nQbAwnMXs/AAAAAAAAAAI/AAAAAAAAABc/yXa8EfpQ6K8/photo.jpg", 
                   :last_name=>"Kumar", 
                   :name=>"Bala Kumar"
                  },
        'provider' => "google_oauth2",
        :uid=>"116155779926622689580"}) 
    get :create, :code=>"4/CnG0syz1np5oJ-NU3kWCIxa93UNDzoUuBOtr6SrOLDQ.EkqAQT0OzhEVcp7tdiljKKY_zEW2mQI", :provider=>"google_oauth2"
    response.location.should eql "#{portal_url}/integrations/user_credentials/oauth_install/google_calendar"
  end

  # This should be changed to use the new OAuth2 credentials. Follow the same model that is done for Google Calendar.
  it "should create authorization for google contacts" do 
    @request.env["omniauth.origin"] = "id=1&portal_id=1&iapp_id=3&app_name=google_contacts"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      { :credentials => { :expires => true,
                          :expires_at => "1429604886",
                          :refresh_token => "1/oN_ue3z0Bi9HDQS2A30GUA8Lxh6Yw0zmJxZ9gpXZFkMMEudVrK5jSpoR30zcRFq6",
                          "token" => "ya29.XAHKpQSKdIitH2teAaEIDZkgjltwa12KG-u7lcsPZ19jrxJH5e9UVjsp4h1L54oJy82Fle6haVpmcQ"
                        }, 
        :extra => { :raw_info => { :email => "bala@freshdesk.com",
                                   :family_name=>"Kumar", 
                                   :gender=>"male", 
                                   :given_name=>"Bala", 
                                   :hd=>"freshdesk.com", 
                                   :id=>"116155779926622689580",
                                   :link=>"https://plus.google.com/+BalaKumarSM", 
                                   :locale=>"en", 
                                   :name=>"Bala Kumar", 
                                   :picture=>"https://lh5.googleusercontent.com/-o3nQbAwnMXs/AAAAAAAAAAI/AAAAAAAAABc/yXa8EfpQ6K8/photo.jpg", 
                                   :verified_email=>true
                                  }
                  },
        :info => { :email=>"bala@freshdesk.com", 
                   :first_name=>"Bala", 
                   :image=>"https://lh5.googleusercontent.com/-o3nQbAwnMXs/AAAAAAAAAAI/AAAAAAAAABc/yXa8EfpQ6K8/photo.jpg", 
                   :last_name=>"Kumar", 
                   :name=>"Bala Kumar"
                  },
        'provider' => "google_contacts",
        :uid=>"116155779926622689580"}) 
    get :create, :code=>"4/hZQgEheYCv4YPoHwhAyVeVCzFnf3DY64dIvgUhfaqVI.Uvmomzjs_coecp7tdiljKKb56cC1mQI", :provider=>"google_contacts"
    response.location.should eql "#{portal_url}/integrations/applications/oauth_install/google_contacts"
  end

  it "should create authorization for mailchimp" do 
    @request.env["omniauth.origin"] = "id=#{@account.id}"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      { :credentials => {
                          :expires => true, 
                          :expires_at => "1403618073",
                          :token => "2a5fd25174113b11cfbcefd2b9e4e909"
                        }, 
        :extra => {
                    :metadata => { :accountname=>"sathishfreshdesk",
                                    :api_endpoint=>"https://us8.api.mailchimp.com",
                                    :login_url=>"https://login.mailchimp.com",
                                    :role=>"owner",
                                    :dc=>"us8"
                                  }
                  },
        :provider=>"mailchimp",
        :uid=>"996f8bc50b4c6c88009934d6a"})
    get :create, :code=>"5e1f89f7246defb1586b31d12ddbadd5", :provider=>"mailchimp"
    response.location.should eql "#{portal_url}/integrations/applications/oauth_install/mailchimp"
  end

  it "should create authorization for twitter" do
    @request.env["omniauth.origin"] = "http://localhost.freshpo.com/support/login"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
    {
      :credentials => { :secret => "zA0MiSwZRpOM5PaTiEfvITEDvDGwwkJoAmocmhPJTVKOE",
                        :token => "320555803-qbVOzx8HMH10WwSnlSYZcRMrOQDYTfS4SBkHDkLh"
                      },
      :info => { :description=>"", 
                 :image=>"http://pbs.twimg.com/profile_images/378800000534384645/68d34547a728dfcc5236021e5beb7e84_normal.jpeg", 
                 :location=>"",
                 :name=>"sathish babu.R", 
                 :nickname=>"satbuceg"
                },
      :provider=>"twitter",
      :uid=>"320555803"
    })
    get :create, :oauth_token=>"N1n8Qwfv33QPReAFSLds2Rtcgd1hFDz87bTQebA", 
                 :oauth_verifier=>"xnalvyPIgjAd8xx2YsjanwR3sxzNA8tSD0PI0Tgs",
                 :provider=>"twitter"
     response.location.should include("http://localhost.freshpo.com/")
  end

  it "should create authorization for facebook" do
    @request.env["omniauth.origin"] = "id=#{@account.id}&portal_id=#{@account.main_portal.id}"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
    {
      :credentials => { :expires => true,
                        :expires_at => "1408863724", 
                        :token=>"CAAEAZCZBjCXkwBAHsAqBky6OhZC8p1Pnq9yTeOQsOZCveDcJtgnjv2WDNoXmmtTZAguKzk3Us9X44h3OIEW2m8E9byF5myPe7HbfyxTp4c3aLv9Y7wd7uVbzywOWrJjyrp0zXgCn760Usf35IZAqh9twYAMMFqESZA9sZAOb0i5EwJfUwZAubR20w6xomemDZCl2EZD"
                      },
      :info => { :email=>"satbruceitan@gmail.com", 
                 :first_name=>"Sathish", 
                 :image=>"http://graph.facebook.com/100001393908238/picture?type=square",
                 :last_name=>"Babu", 
                 :location=>"Chennai, Tamil Nadu", 
                 :name=>"Sathish Babu", 
                 :nickname=>"satbruceitan",
                 :urls=>{ :Facebook=>"https://www.facebook.com/satbruceitan"}
                },
      :provider=>"facebook",
      :uid=>"100001393908238"
    })
    curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
    random_hash = Digest::MD5.hexdigest(curr_time)
    get :create, :code=>"AQDjdI9SsCgBO0lVW2rFkd2-9XS1tGSHOowIkWcX4B1d4gTKziwBJTjeLbSUwGTuVqbEUXWPL3mrOcaMkZexUO2PRPwJF1M5RprgrtdFjV_tL9RL5hzFgjpASsB2s3NVZFdE_n65jXA_webfRQ8GTv-08YBaajbNqGKDyCc7j9Jnupi_O9ADDUis6boEdBkYlc4XAgvXGCDbtzomAiSOu1C0IY8Gt_z0vu2CWLl93sPYMyk2c_Fq0dU1y0I1hWi_xb0GzRDeEFRx9rbCU43-VEwVTkwWfjPqBvTYOdochDnQqOn_A8UtnRhlFYMpE2ExlkU",
                 :provider=>"facebook"
     response.location.should include("/sso/login?provider=facebook&uid=100001393908238")
  end

  it "should create authorization for google calendar" do
    @request.env["omniauth.origin"] = "id=#{@account.id}&app_name=google_calendar&user_id=1"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      { :credentials => { :expires => true,
                          :expires_at => "1429609241",
                          :refresh_token => "1/tNVnf_juKFRDSygGBGtCz0vyEXKz1JwKhID_AgD8LMs",
                          "token" => "ya29.XAH7EFHaE5nCOBXDQmiJxYRpQf3Ss-hTsnLSStXiQ7jrPdiyDIDA3gryYF8yDo1gpcU1SjHr-Omq8g"
                        }, 
        :extra => { :raw_info => { :email => "bala@freshdesk.com",
                                   :family_name=>"Kumar", 
                                   :gender=>"male", 
                                   :given_name=>"Bala", 
                                   :hd=>"freshdesk.com", 
                                   :id=>"116155779926622689580",
                                   :link=>"https://plus.google.com/+BalaKumarSM", 
                                   :locale=>"en", 
                                   :name=>"Bala Kumar", 
                                   :picture=>"https://lh5.googleusercontent.com/-o3nQbAwnMXs/AAAAAAAAAAI/AAAAAAAAABc/yXa8EfpQ6K8/photo.jpg", 
                                   :verified_email=>true
                                  }
                  },
        :info => { :email=>"bala@freshdesk.com", 
                   :first_name=>"Bala", 
                   :image=>"https://lh5.googleusercontent.com/-o3nQbAwnMXs/AAAAAAAAAAI/AAAAAAAAABc/yXa8EfpQ6K8/photo.jpg", 
                   :last_name=>"Kumar", 
                   :name=>"Bala Kumar"
                  },
        'provider' => "google_oauth2",
        :uid=>"116155779926622689580"})
    temp = Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH
    Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH = nil
    get :create, :code=>"4/AjFGM3kabI0u9GpZlIrA2MLyjNWr.AsBTJLpfhu8cdJfo-QBMszueosWGjQI", :provider=>"google_oauth2"
    response.location.should eql "#{portal_url}/integrations/user_credentials/oauth_install/google_calendar"
    Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH = temp
  end

  it "should fail for mailchimp" do 
    @request.env["omniauth.origin"] = "id=#{@account.id}"
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new()
    get :create, :code=>"5e1f89f7246defb1586b31d12ddbadd5", :provider=>"mailchimp"
    response.should redirect_to "#{portal_url}/integrations/applications"
  end
end

require_relative '../test_helper'
require 'minitest/spec'

class EventProcessorExtensionTest < ActiveSupport::TestCase
  def setup
    super
    @test_obj = Object.new
    @test_obj.extend(Freshid::V2::EventProcessorExtensions)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_freshid_default_sso_setup
    payload = {
        "actor"=>{"actor_type"=>"USER", "user_agent"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36", "ip_address"=>"40.131.47.162", "actor_name"=>"mpocock@misshalls.org", "actor_id"=>"145854596706551922"},
        "authentication_module"=>{
            "enable"=>true,
            "enforcement_level"=>"N/A",
            "id"=>"152516591931284152",
            "organisation_id"=>"145854596672997485",
            "debug_enabled"=>true,
            "type"=>"SAML",
            "update_time"=>"2020-02-25T22:12:43Z"
        },
        "event_type"=>"AUTHENTICATION_MODULE_UPDATED",
        "organisation_id"=>"145854596672997485",
        "request_id"=>"65afe207da204222-541bf429b3e33204-1-693a3f5837d6a0c9",
        "action_epoch"=>1582668763.283
    }.deep_symbolize_keys


    @test_obj.authentication_module_updated_event_callback(payload)
    assert "true", @account.sso_enabled.to_s
    assert "true", @account.freshid_saml_sso_enabled?.to_s
  end

  def test_freshid_default_sso_setup_disable
    payload = {
        "actor"=>{"actor_type"=>"USER", "user_agent"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36", "ip_address"=>"40.131.47.162", "actor_name"=>"mpocock@misshalls.org", "actor_id"=>"145854596706551922"},
        "authentication_module"=>{
            "enable"=>false,
            "enforcement_level"=>"N/A",
            "id"=>"152516591931284152",
            "organisation_id"=>"145854596672997485",
            "debug_enabled"=>true,
            "type"=>"SAML",
            "update_time"=>"2020-02-25T22:12:43Z"
        },
        "event_type"=>"AUTHENTICATION_MODULE_UPDATED",
        "organisation_id"=>"145854596672997485",
        "request_id"=>"65afe207da204222-541bf429b3e33204-1-693a3f5837d6a0c9",
        "action_epoch"=>1582668763.283
    }.deep_symbolize_keys


    @test_obj.authentication_module_updated_event_callback(payload)
    assert "false", @account.sso_enabled.to_s
    assert "false", @account.freshid_saml_sso_enabled?.to_s
  end

  def test_freshid_custom_sso_setup
    payload = {
        :actor => {:actor_id => "148031922714001456", :actor_type => "USER", :actor_name => "ronak.poriya@freshworks.com", :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:74.0) Gecko/20100101 Firefox/74.0" },
        :entrypoint => {
            :portals => [{:name => "secsettkngs_swiggy", :url => "http://swiggy.freshdesk.com/swiggyDunzo", :id => "159326119446134795", :account_id => "148031922663669877", :organisation_id => "145854596672997485" }],
            :entrypoint_enabled => "true",
            :slug => "entry2",
            :modules => [
                {
                    :enabled => true,
                    :config => {
                        :size => 8,
                        :logo_uri => "/assets/images/works.svg",
                        :enforcement_level => "PASSWORD_CHANGE",
                        :password_expiry_days => 0,
                        :display_name => "Login with password",
                        :ui_redirect_uri => "https://secsettings.vahlok.freshworksapi.io/sp/PASSWORD/148031922600755244/login",
                        :logout_url => " ",
                        :history_count => 0,
                        :policy_level => "LOW",
                        :special_characters_count => 0,
                        :numeric_characters_count => 0,
                        :mixed_case_characters_count => 0,
                        :type => "PASSWORD",
                        :session_max_inactive => 0
                    },
                    :id => "148031922600755244",
                    :debug_enabled => false,
                    :type => "PASSWORD",
                    :custom_sso => false,
                    :entrypoint_id => "159325420343738375"
                },
                {
                    :enabled => false,
                    :config => {
                        :logo_uri => "https://accounts.vahlok.freshworksapi.io/assets/images/google_logo.svg", :token_uri => "https://oauth2.googleapis.com/token",
                        :scopes => "openid,email,profile", :display_name => "Login with google",
                        :ui_redirect_uri => "https://accounts.vahlok.freshworksapi.io/sp/OIDC/119746749815914501/login",
                        :redirect_uri => "https://accounts.vahlok.freshworksapi.io/sp/OIDC/119746749815914501/callback",
                        :client_id => "252648225933-9969rij4m6of2uuheomkn28gb6qv8tp7.apps.googleusercontent.com",
                        :authorization_uri => "https://accounts.google.com/o/oauth2/v2/auth",
                        :claims => {:first_name => "given_name", :email_verified => true, :company_name => "company_name", :email => "email", :job_title => "job_title", :id => "sub", :last_name => "family_name", :middle_name => "middle_name", :mobile => "mobile", :phone => "phone_number"
                        },
                        :client_secret => "dK_HwArKrS2BpxtVHJzowl4z",
                        :enable_signature_validation => true,
                        :type => "oidc"
                    },
                    :id => "119746749815914501",
                    :debug_enabled => false,
                    :type => "GOOGLE", :custom_sso => false, :entrypoint_id => "159325420343738375"
                },
                {:enabled=>true, :config=>{:signing_options=>"ASSERTION_UNSIGNED_MESSAGE_SIGNED", :ui_redirect_uri=>"https://dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/login", :entity_url=>"https://dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/metadata", :type=>"SAML", :session_max_inactive=>0, :saml_http_binding=>"HTTP_POST", :assertion_url=>"https://dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/callback"}, :id=>"162108483188293633", :debug_enabled=>true,
                 :type=>"SAML",
                 :custom_sso=>true,
                 :entrypoint_id=>"159325420343738375"
                }
            ],
            :user_type => "AGENT",
            :entrypoint_url => "https://secsettings.vahlok.freshworksapi.io/login/auth/entry2",
            :"organisation_id" => "145854596672997485",
            :title => "Custom Method 22",
            :entrypoint_id => "159325420343738375",
            :accounts => [
                {
                    :name => "secsettting",
                    :domain => "secsettings.freshdesk.com",
                    :id => "148031922663669877",
                    :status => "ACTIVATED",
                    :organisation_id => "145854596672997485",
                    :product_id => "129503096757649409",
                    :external_id => "1",
                    :update_time => "2020-02-13T11:46:00Z",
                    :create_time => "2020-02-13T11:46:00Z"
                }]
        },
        :event_type => "ENTRYPOINT_DELETED",
        :organisation_id => "145854596672997485", :request_id => "690c2927e12026bd-d6293b662528bc7f-1-4c066f9ed04d05e3", :action_epoch => 1585717412.123
    }

    sso_changes = @test_obj.safe_send("scrape_sso_changes", payload[:entrypoint][:modules])
    entry_attrs = @test_obj.safe_send("entrypoint_attrs", payload[:entrypoint])

    @test_obj.safe_send("process_custom_freshid_sso_events", sso_changes, entry_attrs, payload[:entrypoint][:user_type])
    assert "true", @account.sso_enabled.to_s
    assert "true", @account.freshid_sso_enabled?.to_s
  end

  def test_freshid_custom_sso_setup_disable
    payload = {
        :actor => {:actor_id => "148031922714001456", :actor_type => "USER", :actor_name => "ronak.poriya@freshworks.com", :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:74.0) Gecko/20100101 Firefox/74.0" },
        :entrypoint => {
            :portals => [{:name => "secsettkngs_swiggy", :url => "http://swiggy.freshdesk.com/swiggyDunzo", :id => "159326119446134795", :account_id => "148031922663669877", :organisation_id => "145854596672997485" }],
            :entrypoint_enabled => "true",
            :slug => "entry2",
            :modules => [
                {
                    :enabled => true,
                    :config => {
                        :size => 8,
                        :logo_uri => "/assets/images/works.svg",
                        :enforcement_level => "PASSWORD_CHANGE",
                        :password_expiry_days => 0,
                        :display_name => "Login with password",
                        :ui_redirect_uri => "https://secsettings.vahlok.freshworksapi.io/sp/PASSWORD/148031922600755244/login",
                        :logout_url => " ",
                        :history_count => 0,
                        :policy_level => "LOW",
                        :special_characters_count => 0,
                        :numeric_characters_count => 0,
                        :mixed_case_characters_count => 0,
                        :type => "PASSWORD",
                        :session_max_inactive => 0
                    },
                    :id => "148031922600755244",
                    :debug_enabled => false,
                    :type => "PASSWORD",
                    :custom_sso => false,
                    :entrypoint_id => "159325420343738375"
                },
                {
                    :enabled => false,
                    :config => {
                        :logo_uri => "https://accounts.vahlok.freshworksapi.io/assets/images/google_logo.svg", :token_uri => "https://oauth2.googleapis.com/token",
                        :scopes => "openid,email,profile", :display_name => "Login with google",
                        :ui_redirect_uri => "https://accounts.vahlok.freshworksapi.io/sp/OIDC/119746749815914501/login",
                        :redirect_uri => "https://accounts.vahlok.freshworksapi.io/sp/OIDC/119746749815914501/callback",
                        :client_id => "252648225933-9969rij4m6of2uuheomkn28gb6qv8tp7.apps.googleusercontent.com",
                        :authorization_uri => "https://accounts.google.com/o/oauth2/v2/auth",
                        :claims => {:first_name => "given_name", :email_verified => true, :company_name => "company_name", :email => "email", :job_title => "job_title", :id => "sub", :last_name => "family_name", :middle_name => "middle_name", :mobile => "mobile", :phone => "phone_number"
                        },
                        :client_secret => "dK_HwArKrS2BpxtVHJzowl4z",
                        :enable_signature_validation => true,
                        :type => "oidc"
                    },
                    :id => "119746749815914501",
                    :debug_enabled => false,
                    :type => "GOOGLE", :custom_sso => false, :entrypoint_id => "159325420343738375"
                },
                {:enabled=>false, :config=>{:signing_options=>"ASSERTION_UNSIGNED_MESSAGE_SIGNED", :ui_redirect_uri=>"https://dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/login", :entity_url=>"https://dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/metadata", :type=>"SAML", :session_max_inactive=>0, :saml_http_binding=>"HTTP_POST", :assertion_url=>"https://dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/callback"}, :id=>"162108483188293633", :debug_enabled=>true,
                 :type=>"SAML",
                 :custom_sso=>true,
                 :entrypoint_id=>"159325420343738375"
                }
            ],
            :user_type => "AGENT",
            :entrypoint_url => "https://secsettings.vahlok.freshworksapi.io/login/auth/entry2",
            :"organisation_id" => "145854596672997485",
            :title => "Custom Method 22",
            :entrypoint_id => "159325420343738375",
            :accounts => [
                {
                    :name => "secsettting",
                    :domain => "secsettings.freshdesk.com",
                    :id => "148031922663669877",
                    :status => "ACTIVATED",
                    :organisation_id => "145854596672997485",
                    :product_id => "129503096757649409",
                    :external_id => "1",
                    :update_time => "2020-02-13T11:46:00Z",
                    :create_time => "2020-02-13T11:46:00Z"
                }]
        },
        :event_type => "ENTRYPOINT_DELETED",
        :organisation_id => "145854596672997485", :request_id => "690c2927e12026bd-d6293b662528bc7f-1-4c066f9ed04d05e3", :action_epoch => 1585717412.123
    }

    sso_changes = @test_obj.safe_send("scrape_sso_changes", payload[:entrypoint][:modules])
    entry_attrs = @test_obj.safe_send("entrypoint_attrs", payload[:entrypoint])

    @test_obj.safe_send("process_custom_freshid_sso_events", sso_changes, entry_attrs, payload[:entrypoint][:user_type])
    assert "false", @account.sso_enabled.to_s
    assert "false", @account.freshid_sso_enabled?.to_s
  end
end

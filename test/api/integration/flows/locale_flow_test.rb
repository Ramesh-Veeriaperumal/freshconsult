require_relative '../../test_helper'

class LocaleFlowTest < ActionDispatch::IntegrationTest

  TEST_LOCALES = ["fr", "de"]
  
  def setup
    super
    TEST_LOCALES.each do |test_locale|
      instance_variable_set("@#{test_locale}_agent", add_test_agent)
      agent_obj = instance_variable_get("@#{test_locale}_agent")
      agent_obj.language = test_locale
      agent_obj.password = "test1234"
      agent_obj.password_confirmation = "test1234"
      agent_obj.save
    end
    UserSession.any_instance.unstub(:cookie_credentials)
  end

  def teardown
    super
    I18n.locale = I18n.default_locale
  end

  def test_default_locale_for_v2_api
    login_agent(@fr_agent)
    get "/api/v2/tickets"
    assert_response 200
    assert_equal I18n.locale, I18n.default_locale
  end

  def test_locale_switch_across_private_api
    login_agent(@fr_agent)
    get '/api/_/bootstrap'
    assert_response 200
    assert_equal I18n.locale.to_s, @fr_agent.language
    login_agent(@de_agent)
    get '/api/_/tickets'
    assert_response 200
    assert_equal I18n.locale.to_s, @de_agent.language
  end

  def login_agent(agent)
    post "/user_session", :user_session=>{:email=> agent.email, :password=>"test1234", :remember_me=>"1"}
  end
end

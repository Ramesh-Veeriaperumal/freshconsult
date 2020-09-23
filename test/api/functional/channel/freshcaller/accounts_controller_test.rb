require_relative '../../../test_helper'
class Channel::Freshcaller::AccountsControllerTest < ActionController::TestCase
	include ::Freshcaller::JwtAuthentication
	
	def setup
    super
    initial_setup
  end

  def teardown
    super
    @account.revoke_feature(:freshcaller)
    CustomRequestStore.store[:private_api_request] = @initial_private_api_request
  end

  @initial_setup_run = false

  def initial_setup
    @initial_private_api_request = CustomRequestStore.store[:private_api_request]
    CustomRequestStore.store[:private_api_request] = true
    @account.reload
    return if @initial_setup_run
    @account.add_feature(:freshcaller)
    ::Freshcaller::Account.new(account_id: @account.id).save
    @account.reload
    @account.save
    @initial_setup_run = true
  end


  def test_destroy_with_invalid_auth
  	invalid_auth_header
    delete :destroy, construct_params(version: 'channel')
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

   def test_destroy_with_valid_params_and_basic_auth
    set_basic_auth_header
    delete :destroy, construct_params(version: 'channel')
    result = parse_response(@response.body)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:no_content]
  end

  def test_destroy_with_valid_params_and_jwt_auth
    set_auth_header
    delete :destroy, construct_params(version: 'channel')
    result = parse_response(@response.body)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:no_content]
  end

  def test_update_domain_with_invalid_auth
    invalid_auth_header
    put :update, construct_params(version: 'channel', domain: 'abc.freshcaller.com')
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

  def test_update_domain_with_valid_params_and_basic_auth
    set_basic_auth_header
    put :update, construct_params(version: 'channel', domain: 'abc.freshcaller.com')
    assert_equal @account.freshcaller_account.domain, 'abc.freshcaller.com'
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:no_content]
  end

  def test_update_domain_with_valid_params_and_jwt_auth
    set_auth_header
    put :update, construct_params(version: 'channel', domain: 'abc.freshcaller.com')
    assert_equal @account.freshcaller_account.domain, 'abc.freshcaller.com'
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:no_content]
  end

  def test_update_domain_with_invalid_params
    set_auth_header
    put :update, construct_params(version: 'channel', invalid_domain: 'abc.freshcaller.com')
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request]
  end

  private

    def set_auth_header
      request.env['HTTP_AUTHORIZATION'] = "token=#{sign_payload({'account_id': '1', 'api_key': 'xxx' })}"
    end

    def invalid_auth_header
      request.env['HTTP_AUTHORIZATION'] = "token=invalid"
    end

    def set_basic_auth_header
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, "X")
    end


end
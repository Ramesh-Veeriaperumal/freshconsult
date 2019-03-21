require_relative '../../../test_helper'
class Channel::OmniChannelRouting::LinkedAccountsControllerTest < ActionController::TestCase
  include LinkedAccountsTestHelper

  def test_index_with_both
    link_freshchat
    link_freshcaller
    @account.reload
    append_header
    expected_json = { accounts: [{ id: @account.id.to_s, product: 'freshdesk', domain: @account.full_domain }, { id: @freshchat.app_id, product: 'freshchat', domain: 'freshchat.com', enabled: true }, { id: @freshcaller.freshcaller_account_id.to_s, product: 'freshcaller', domain: @freshcaller.domain }] }
    get :index, controller_params(version: 'channel/ocr/accounts')
    match_json(expected_json)
    assert_response 200
  ensure
    remove_freshchat
    remove_freshcaller
    @account.reload
  end

  def test_index_without_freshchat
    link_freshcaller
    @account.reload
    append_header
    expected_json = { accounts: [{ id: @account.id.to_s, product: 'freshdesk', domain: @account.full_domain }, { id: @freshcaller.freshcaller_account_id.to_s, product: 'freshcaller', domain: @freshcaller.domain }] }
    get :index, controller_params(version: 'channel/ocr/accounts')
    match_json(expected_json)
    assert_response 200
  ensure
    remove_freshcaller
    @account.reload
  end

  def test_index_without_freshcaller
    link_freshchat
    @account.reload
    append_header
    expected_json = { accounts: [{ id: @account.id.to_s, product: 'freshdesk', domain: @account.full_domain }, { id: @freshchat.app_id, product: 'freshchat', domain: 'freshchat.com', enabled: true }] }
    get :index, controller_params(version: 'channel/ocr/accounts')
    assert_response 200
  ensure
    remove_freshchat
    @account.reload
  end

  def test_index_without_freshcaller_and_freshchat
    @account.stubs(:freshcaller_account).returns(nil)
    @account.stubs(:freshchat_account).returns(nil)
    append_header
    expected_json = { accounts: [{ id: @account.id.to_s, product: 'freshdesk', domain: @account.full_domain }] }
    get :index, controller_params(version: 'channel/ocr/accounts')
    match_json(expected_json)
    assert_response 200
  ensure
    @account.reload
    @account.unstub(:freshcaller_account)
    @account.unstub(:freshchat_account)
  end
end

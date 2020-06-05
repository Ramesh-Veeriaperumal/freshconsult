require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class GoogleAccountTest < ActionView::TestCase
  include AccountHelper

  def setup
    super
    before_all
    ::XmlSimple.stubs(:xml_in).returns('id' => [])
    Integrations::GoogleAccount.any_instance.stubs(:email).returns('mail')
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account = create_test_account
    Account.stubs(:first).returns(Account.current)
    @@before_all_run = true
  end

  def params(params_id = [])
    { :integrations_google_account => { :id => params_id, :account => Account.current } }
  end

  def teardown
    Integrations::GoogleAccount.any_instance.unstub(:email)
    ::XmlSimple.unstub(:xml_in)
    super
  end

  def test_find_or_create
    Integrations::GoogleAccount.find_or_create(params(1), Account.current)
    assert_equal response.status, 200
    google_account = Integrations::GoogleAccount.find_or_create({ integrations_google_account:
      { token: Faker::Lorem.characters(6), secret: Faker::Lorem.characters(6) } }, Account.current)
    google_account.save!
    assert_not_nil google_account.encrypted_token
    assert_not_nil google_account.encrypted_secret
    assert_equal google_account.token, SymmetricEncryption.decrypt(google_account.encrypted_token)
    assert_equal google_account.secret, SymmetricEncryption.decrypt(google_account.encrypted_secret)
    assert_equal response.status, 200
  end

  def test_create_google_group
    Integrations::GoogleAccount.any_instance.stubs(:prepare_access_token).returns(OAuth2::AccessToken.from_hash('client', {}))
    OAuth2::AccessToken.any_instance.stubs(:post).returns(ActionController::TestResponse.new(status = 200))
    Integrations::GoogleAccount.any_instance.stubs(:auth_oauth2?).returns(false)
    Integrations::OauthHelper.stubs(:get_oauth_keys).returns({})
    OAuth::AccessToken.any_instance.stubs(:post).returns(ActionController::TestResponse.new(status = 200, body = { 'refresh_token' => [1] }))
    resp = Integrations::GoogleAccount.new.create_google_group('param1', 'params2')
    assert_equal resp, nil
    Integrations::GoogleAccount.any_instance.unstub(:prepare_access_token)
    OAuth::AccessToken.any_instance.stubs(:post).returns(ActionController::TestResponse.new(status = 200, header = '{}', body = { 'refresh_token' => OAuth2::AccessToken.new(1, 2) }.to_json))
    Integrations::GoogleAccount.any_instance.stubs(:enable_integration).returns(true)
    Integrations::GoogleAccount.any_instance.stubs(:get_oauth2_access_token).returns(OAuth2::AccessToken.new(1, 2))
    Integrations::GoogleAccount.new.create_google_group('param1', 'params2')
    assert_equal response.status, 200
  ensure
    Integrations::OauthHelper.unstub(:get_oauth2_access_token)
    Integrations::GoogleAccount.any_instance.unstub(:enable_integration)
    OAuth::AccessToken.any_instance.unstub(:post)
    Integrations::OauthHelper.unstub(:get_oauth_keys)
    Integrations::GoogleAccount.any_instance.stubs(:auth_oauth2?).returns(false)
    OAuth2::AccessToken.any_instance.unstub(:post)
    Integrations::GoogleAccount.any_instance.unstub(:prepare_access_token)
  end

  def test_fetch_all_google_groups
    Integrations::GoogleAccount.any_instance.stubs(:prepare_access_token).returns(OAuth2::AccessToken.from_hash('client', {}))
    OAuth2::AccessToken.any_instance.stubs(:post).returns(ActionController::TestResponse.new(status = 200))
    Integrations::GoogleAccount.any_instance.stubs(:auth_oauth2?).returns(false)
    Integrations::OauthHelper.stubs(:get_oauth_keys).returns({})
    Integrations::OauthHelper.stubs(:get_oauth2_access_token).returns({})
    OAuth2::AccessToken.any_instance.stubs(:post).returns(ActionController::TestResponse.new(status = 200, body = { 'refresh_token' => [1] }))
    OAuth2::AccessToken.any_instance.stubs(:get).returns(ActionController::TestResponse.new(status = 200, body = { 'refresh_token' => [1] }))
    resp = Integrations::GoogleAccount.new.fetch_all_google_groups('param', false)
    assert_equal resp.to_json, [{"group_id"=>"6", "name"=>"My Contacts"}].to_json
    assert_equal response.status, 200
  ensure
    OAuth::AccessToken.any_instance.unstub(:post)
    OAuth::AccessToken.any_instance.unstub(:get)
    Integrations::OauthHelper.unstub(:get_oauth_keys)
    Integrations::GoogleAccount.any_instance.stubs(:auth_oauth2?).returns(false)
    OAuth2::AccessToken.any_instance.unstub(:post)
    OAuth2::AccessToken.any_instance.unstub(:get)
    Integrations::GoogleAccount.any_instance.unstub(:prepare_access_token)
    Integrations::OauthHelper.unstub(:get_oauth2_access_token)
  end

  def test_fetch_all_google_contacts
    Integrations::GoogleAccount.new.reset_start_index
  end

  def test_fetch_latest_google_contacts
    Integrations::GoogleAccount.any_instance.stubs(:import_groups).returns('g_group_id' => 1)
    Integrations::GoogleAccount.any_instance.stubs(:last_sync_time).returns(0)
    Integrations::GoogleAccount.any_instance.stubs(:last_sync_index).returns(0)
    Integrations::GoogleAccount.any_instance.stubs(:prepare_access_token).returns(OAuth2::AccessToken.from_hash('client', {}))
    OAuth2::AccessToken.any_instance.stubs(:get).returns(ActionController::TestResponse.new(status = 200, body = { 'refresh_token' => [1] }))
    Nokogiri::XML::Document.any_instance.stubs(:xpath).returns([1, 2])
    Integrations::GoogleAccount.any_instance.stubs(:parse_user_xml).returns(GoogleContact.new)
    Integrations::GoogleAccount.new.fetch_latest_google_contacts(0, 'none', Time.at(0))
    assert_equal response.status, 200
  ensure
    Integrations::GoogleAccount.any_instance.unstub(:parse_user_xml)
    Nokogiri::XML::Document.any_instance.unstub(:xpath)
    OAuth2::AccessToken.any_instance.unstub(:get)
    Integrations::GoogleAccount.any_instance.unstub(:prepare_access_token)
    Integrations::GoogleAccount.any_instance.unstub(:import_groups)
    Integrations::GoogleAccount.any_instance.unstub(:last_sync_time)
    Integrations::GoogleAccount.any_instance.unstub(:last_sync_index)
  end

  def test_batch_update_google_contacts
    Integrations::GoogleAccount.any_instance.stubs(:prepare_access_token).returns(OAuth2::AccessToken.from_hash('client', {}))
    OAuth2::AccessToken.any_instance.stubs(:post).returns(ActionController::TestResponse.new(status = 200))
    resp = Integrations::GoogleAccount.new.batch_update_google_contacts([User.new], 0)
    assert_equal response.status, 200
    assert_equal [[0, 0, 0], [0, 0, 0]], resp
    Integrations::GoogleAccount.any_instance.stubs(:fetch_current_account_contact).returns({})
    ::XmlSimple.stubs(:xml_in).returns('entry' => [{ 'id' => ['create'], 'status' => [{ 'code' => 200 }] }])
    resp = Integrations::GoogleAccount.new.batch_update_google_contacts([User.new], 0) 
    assert_equal [[0, 0, 0], [1, 0, 0]], resp
    assert_equal response.status, 200# raise exception at 461
    Integrations::GoogleAccount.any_instance.stubs(:fetch_current_account_contact).returns(nil)
    resp = Integrations::GoogleAccount.new.batch_update_google_contacts([User.new], 0)
    assert_equal [[0, 0, 0], [1, 0, 0]], resp
    assert_equal response.status, 200 # raise exception at end of same para
    ::XmlSimple.stubs(:xml_in).returns('entry' => [{ 'id' => ['update'], 'status' => [{ 'code' => '404' }] }])
    Integrations::GoogleAccount.any_instance.stubs(:find_user_by_google_id).returns(User.new)
    resp = Integrations::GoogleAccount.new.batch_update_google_contacts([User.new], 0)
    assert_equal response.status, 200
    User.any_instance.stubs(:google_contacts).returns(0 => 1, 2 => 3)
    Integrations::GoogleAccount.any_instance.stubs(:fetch_current_account_contact).returns(Integrations::GoogleAccount.new.google_contacts.first)
    resp = Integrations::GoogleAccount.new.update_google_contacts([User.new], false, 'not_type')
    assert_equal resp, ''
    assert_equal response.status, 200
  ensure
    User.any_instance.unstub(:google_contact)
    Integrations::GoogleAccount.any_instance.unstub(:find_user_by_google_id)
    Integrations::GoogleAccount.any_instance.unstub(:fetch_current_account_contact)
    ::XmlSimple.unstub(:xml_in)
    Integrations::GoogleAccount.any_instance.unstub(:prepare_access_token)
    OAuth2::AccessToken.any_instance.unstub(:post)
  end

  def test_update_google_contacts
    Integrations::GoogleAccount.any_instance.stubs(:prepare_access_token).returns(OAuth2::AccessToken.from_hash('client', {}))
    Integrations::GoogleAccount.any_instance.stubs(:fetch_current_account_contact).returns(GoogleContact.new(google_id: '1'))
    OAuth2::AccessToken.any_instance.stubs(:put).returns(ActionController::TestResponse.new(status = 200))
    Integrations::GoogleAccount.any_instance.stubs(:covert_to_contact_xml).returns('xml')
    User.any_instance.stubs(:google_contacts).returns([GoogleContact.new(google_id: '1')])
    Integrations::GoogleAccount.new.update_google_contacts([User.new(deleted: false)], false, false)
    assert_equal response.status, 200
    OAuth2::AccessToken.any_instance.stubs(:put).returns(ActionController::TestResponse.new(status = 404))
    Integrations::GoogleAccount.new.update_google_contacts([User.new(deleted: false)], false, false)
    assert_equal response.status, 200
    GoogleContact.stubs(:find_by_user_id).returns(GoogleContact.new)
    OAuth2::AccessToken.any_instance.stubs(:delete).returns(ActionController::TestResponse.new(status = 200))
    Integrations::GoogleAccount.new.update_google_contacts([User.new(deleted: true)], false, false)
    assert_equal response.status, 200
  ensure
    User.any_instance.unstub(:google_contacts)
    GoogleContact.unstub(:find_by_user_id)
    OAuth2::AccessToken.any_instance.unstub(:put)
    OAuth2::AccessToken.any_instance.unstub(:delete)
    Integrations::GoogleAccount.any_instance.unstub(:covert_to_contact_xml)
    Integrations::GoogleAccount.any_instance.unstub(:fetch_current_account_contact)
    Integrations::GoogleAccount.any_instance.unstub(:prepare_access_token)
    OAuth2::AccessToken.any_instance.unstub(:post)
  end
end

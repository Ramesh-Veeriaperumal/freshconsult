require_relative '../../../api/unit_test_helper'
require Rails.root.join('test', 'lib', 'helpers', 'contact_segments_test_helper.rb')
class SlackServiceTest < ActionView::TestCase
  include ::ContactSegmentsTestHelper
  include IntegrationServices::Errors
  def setup
    account = Account.first || create_test_account
    Account.stubs(:current).returns(account)
    user = account.users.first || create_contact
    User.stubs(:current).returns(user)
  end

  def teardown
    super
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_receive_channels_success
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ChannelResource.any_instance.stubs(:list).returns(%w[first second])
    channel = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_channels
    assert_equal false, channel[:error]
    IntegrationServices::Services::Slack::ChannelResource.any_instance.unstub(:list)
  end

  def test_receive_channels_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ChannelResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    channel = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_channels
    assert_equal true, channel[:error]
    IntegrationServices::Services::Slack::ChannelResource.any_instance.unstub(:list)
  end

  def test_receive_groups_success
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::GroupResource.any_instance.stubs(:list).returns(%w[first second])
    group = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_groups
    assert_equal false, group[:error]
    IntegrationServices::Services::Slack::GroupResource.any_instance.unstub(:list)
  end

  def test_receive_groups_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::GroupResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    group = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_groups
    assert_equal true, group[:error]
    IntegrationServices::Services::Slack::GroupResource.any_instance.unstub(:list)
  end

  def test_receive_slash_command
    Rails.logger.info('test_receive_slash_command started')
    contact1 = create_contact
    contact2 = create_contact
    user_list = {members: [{ id: contact1.id, name: 'test_name', profile: { email: contact1.email }.stringify_keys! }
      .stringify_keys!, { id: contact2.id, name: 'new agent', profile: { email: contact2.email }.stringify_keys! }
      .stringify_keys!] }.stringify_keys!
    conversation = { conversation: 'first', user: contact2.id, message: { text: 'test' }.stringify_keys! }
      .stringify_keys!
    IntegrationServices::Services::Slack::AuthResource.any_instance.stubs(:test).returns(auth: true)
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).returns(user_list)
    Integrations::UserCredential.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).returns(true)
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:history).returns([conversation])

    app = Integrations::InstalledApplication.new
    slash = ::IntegrationServices::Services::SlackService.new(app,
      { act_hash: { user_slack_token: 'slack123', event_type: 'create_ticket', user_id: contact1.id } },
                                                              {}).receive_slash_command
    assert_equal true, slash[:post_notice]
    Rails.logger.info('test_receive_slash_command ended')
  ensure
    contact1.destroy
    contact2.destroy
    Integrations::UserCredential.any_instance.unstub(:save!)
    IntegrationServices::Services::Slack::ChatResource.any_instance.unstub(:post_message)
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:history)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
    IntegrationServices::Services::Slack::AuthResource.any_instance.unstub(:test)
  end

  def test_receive_slash_command_nil
    app = Integrations::InstalledApplication.new
    slash = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { user_id: 1 } },
                                                              {}).receive_slash_command
    assert_equal nil, slash
  end

  def test_receive_history_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:history).raises(StandardError.new('exception'))
    history = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_history('token')
    assert_equal true, history[:error]
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:history)
  end

  def test_receive_push_to_slack
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { 'allow_dm': true }.stringify_keys!)
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).returns({ 'members': [{ id: 1,
                                                                                                         name: 'test_name',
                                                                                                         profile: { email: Account.first.technicians.first.email }.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:open).returns(1)
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:responder).returns(Account.first.technicians.first)
    app = Integrations::InstalledApplication.new
    pushed_msg = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { push_to: 'dm_agent' }, act_on_object: Account.first.tickets.first },
                                                                   {}).receive_push_to_slack
    assert_equal true, pushed_msg[:post_notice]
    Integrations::InstalledApplication.any_instance.unstub(:configs)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:open)
    IntegrationServices::Services::Slack::ChatResource.any_instance.unstub(:post_message)
    Helpdesk::Ticket.any_instance.unstub(:responder)
  end

  def test_receive_push_to_slack_pvt_channels
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { 'private_channels': 'channel1' }.stringify_keys!)
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).returns({ 'members': [{ id: 1,
                                                                                                         name: 'test_name',
                                                                                                         profile: { email: Account.first.technicians.first.email }.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:open).returns(1)
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:responder).returns(Account.first.technicians.first)
    app = Integrations::InstalledApplication.new
    pushed_msg = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { push_to: 'channel1' }, act_on_object: Account.first.tickets.first },
                                                                   {}).receive_push_to_slack
    assert_equal true, pushed_msg[:post_notice]
    Integrations::InstalledApplication.any_instance.unstub(:configs)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:open)
    IntegrationServices::Services::Slack::ChatResource.any_instance.unstub(:post_message)
    Helpdesk::Ticket.any_instance.unstub(:responder)
  end

  def test_receive_slash_command_v3_nil
    app = Integrations::InstalledApplication.new
    slash = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { user_id: 1 } },
                                                              {}).receive_slash_command_v3
    assert_equal nil, slash
  end

  def test_receive_slash_command_v3
    Integrations::InstalledApplication.any_instance.stubs(:user_credentials).returns(Integrations::InstalledApplication.new)
    Integrations::InstalledApplication.any_instance.stubs(:find_by_remote_user_id).returns(Integrations::InstalledApplication.new)
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:list).returns(Account.first.users.first.id)
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).returns({ 'members': [{ id: Account.first.users.first.try(:id),
                                                                                                         name: 'test_name',
                                                                                                         profile: { email: Account.first.users.first.try(:email) }.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    IntegrationServices::Services::SlackService.any_instance.stubs(:create_ticket).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:auth_info).returns({ oauth_token: '1234' }.stringify_keys!)
    Integrations::InstalledApplication.any_instance.stubs(:user).returns(Account.first.users.first)
    app = Integrations::InstalledApplication.new
    slash = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { user_id: 1, channel_id: 1 } },
                                                              {}).receive_slash_command_v3
    assert_equal true, slash
    Integrations::InstalledApplication.any_instance.unstub(:user_credentials)
    Integrations::InstalledApplication.any_instance.unstub(:find_by_remote_user_id)
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:list)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
    IntegrationServices::Services::SlackService.any_instance.unstub(:create_ticket)
    Integrations::InstalledApplication.any_instance.unstub(:auth_info)
    Integrations::InstalledApplication.any_instance.unstub(:user)
  end

  def test_receive_open_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:open).raises(StandardError.new('exception'))
    open = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_open(1)
    assert_equal true, open[:error]
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:open)
  end

  def test_receive_auth_info_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::AuthResource.any_instance.stubs(:test).raises(StandardError.new('exception'))
    auth = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_auth_info
    assert_equal true, auth[:error]
    IntegrationServices::Services::Slack::AuthResource.any_instance.unstub(:test)
  end

  def test_receive_users_list_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    NewRelic::Agent.expects(:notice_error).once
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal true, list[:error]
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
  end

  def test_receive_users_list_with_ratelimit_err
    app = Integrations::InstalledApplication.new
    response = { ok: false, error: 'ratelimited' }.to_json
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 429
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:slack_token).returns('token')
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:http_get).returns(response_mock)
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal 'Error message: ratelimited', list[:error_message]
    assert_equal true, list[:error]
  ensure
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:slack_token)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:http_get)
  end

  def test_receive_users_list_with_token_revoked_err
    app = Integrations::InstalledApplication.new
    response = { ok: false, error: 'token_revoked' }.to_json
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:slack_token).returns('token')
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:http_get).returns(response_mock)
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal 'Error message: token_revoked', list[:error_message]
    assert_equal true, list[:error]
  ensure
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:slack_token)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:http_get)
  end

  def test_receive_users_list_with_remote_err
    app = Integrations::InstalledApplication.new
    response = { ok: false, error: 'remote_error' }.to_json
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 400
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:slack_token).returns('token')
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:http_get).returns(response_mock)
    NewRelic::Agent.expects(:notice_error).once
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal true, list[:error]
  ensure
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:slack_token)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:http_get)
  end

  def test_receive_users_list_with_unhandled_err
    app = Integrations::InstalledApplication.new
    response = { ok: false, error: 'unhandled_error' }.to_json
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:slack_token).returns('token')
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:http_get).returns(response_mock)
    NewRelic::Agent.expects(:notice_error).once
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal true, list[:error]
  ensure
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:slack_token)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:http_get)
  end

  def test_receive_users_list_with_ratelimit_err_should_not_push_to_newrelic
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).raises(RatelimitError.new('exception'))
    NewRelic::Agent.expects(:notice_error).never
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal true, list[:error]
  ensure
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
  end

  def test_receive_users_list_with_token_revoked_err_should_not_push_to_newrelic
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).raises(TokenRevokedError.new('exception'))
    NewRelic::Agent.expects(:notice_error).never
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal true, list[:error]
  ensure
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
  end

  def test_receive_post_message_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).raises(StandardError.new('exception'))
    post = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_post_message('bh')
    assert_equal true, post[:error]
    IntegrationServices::Services::Slack::ChatResource.any_instance.unstub(:post_message)
  end

  def test_receive_im_user_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    usr = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_im_user('token', 1)
    assert_equal true, usr[:error]
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:list)
  end

  def test_receive_add_slack
    Integrations::SlackRemoteUser.stubs(:where).returns([])
    Integrations::SlackRemoteUser.stubs(:create!).returns(true)
    app = Integrations::InstalledApplication.new
    add_slack = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_add_slack
    assert_equal true, add_slack
    Integrations::SlackRemoteUser.unstub(:where)
    Integrations::SlackRemoteUser.unstub(:create!)
  end

  def test_receive_remove_slack
    Integrations::SlackRemoteUser.stubs(:where).returns([])
    Integrations::SlackRemoteUser.stubs(:destroy).returns(nil)
    app = Integrations::InstalledApplication.new
    remove_slack = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_remove_slack
    assert_equal nil, remove_slack
    Integrations::SlackRemoteUser.unstub(:where)
    Integrations::SlackRemoteUser.unstub(:destroy)
  end

  def test_receive_slash_command_creating_user
    IntegrationServices::Services::Slack::AuthResource.any_instance.stubs(:test).returns(auth: true)
    User.any_instance.stubs(:signup!).returns(true)
    IntegrationServices::Services::Slack::Processor::TicketProcessor.any_instance.stubs(:create_ticket).returns('ticket_url')
    Integrations::UserCredential.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).returns(true)
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:history).returns(conversation: 'first')
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).returns({ 'members': [{ id: 1,
                                                                                                         name: 'test_name',
                                                                                                         profile: { email: 'abcd' }.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    app = Integrations::InstalledApplication.new
    slash = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { user_slack_token: 'slack123', event_type: 'create_ticket', user_id: 1 } },
                                                              {}).receive_slash_command
    assert_equal true, slash[:post_notice]
    IntegrationServices::Services::Slack::AuthResource.any_instance.unstub(:test)
    User.any_instance.unstub(:signup!)
    IntegrationServices::Services::Slack::Processor::TicketProcessor.any_instance.unstub(:create_ticket)
    Integrations::UserCredential.any_instance.unstub(:save!)
    IntegrationServices::Services::Slack::ChatResource.any_instance.unstub(:post_message)
    IntegrationServices::Services::Slack::ImResource.any_instance.unstub(:history)
    IntegrationServices::Services::Slack::UserResource.any_instance.unstub(:list)
  end
end

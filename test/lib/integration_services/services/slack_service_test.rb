require_relative '../../../api/unit_test_helper'

class SlackServiceTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(Account.first.users.first)
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
  end

  def test_receive_channels_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ChannelResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    channel = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_channels
    assert_equal true, channel[:error]
  end

  def test_receive_groups_success
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::GroupResource.any_instance.stubs(:list).returns(%w[first second])
    group = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_groups
    assert_equal false, group[:error]
  end

  def test_receive_groups_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::GroupResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    group = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_groups
    assert_equal true, group[:error]
  end

  def test_receive_slash_command
    IntegrationServices::Services::Slack::AuthResource.any_instance.stubs(:test).returns(auth: true)
    IntegrationServices::Services::Slack::Processor::TicketProcessor.any_instance.stubs(:create_ticket).returns('ticket_url')
    Integrations::UserCredential.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).returns(true)
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:history).returns(conversation: 'first')
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).returns({ 'members': [{ id: 1,
                                                                                                         name: 'test_name',
                                                                                                         profile: { email: Account.first.users.first.email }.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    app = Integrations::InstalledApplication.new
    slash = ::IntegrationServices::Services::SlackService.new(app, { act_hash: { user_slack_token: 'slack123', event_type: 'create_ticket', user_id: 1 } },
                                                              {}).receive_slash_command
    assert_equal true, slash[:post_notice]
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
  end

  def test_receive_open_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:open).raises(StandardError.new('exception'))
    open = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_open(1)
    assert_equal true, open[:error]
  end

  def test_receive_auth_info_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::AuthResource.any_instance.stubs(:test).raises(StandardError.new('exception'))
    auth = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_auth_info
    assert_equal true, auth[:error]
  end

  def test_receive_users_list_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::UserResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    list = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_users_list
    assert_equal true, list[:error]
  end

  def test_receive_post_message_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ChatResource.any_instance.stubs(:post_message).raises(StandardError.new('exception'))
    post = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_post_message('bh')
    assert_equal true, post[:error]
  end

  def test_receive_im_user_err
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::Slack::ImResource.any_instance.stubs(:list).raises(StandardError.new('exception'))
    usr = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_im_user('token', 1)
    assert_equal true, usr[:error]
  end

  def test_receive_add_slack
    Integrations::SlackRemoteUser.stubs(:where).returns([])
    Integrations::SlackRemoteUser.stubs(:create!).returns(true)
    app = Integrations::InstalledApplication.new
    add_slack = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_add_slack
    assert_equal true, add_slack
  end

  def test_receive_remove_slack
    Integrations::SlackRemoteUser.stubs(:where).returns([])
    Integrations::SlackRemoteUser.stubs(:destroy).returns(nil)
    app = Integrations::InstalledApplication.new
    remove_slack = ::IntegrationServices::Services::SlackService.new(app, { type: 'test' }, {}).receive_remove_slack
    assert_equal nil, remove_slack
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
  end
end

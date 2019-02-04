require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'ticket_helper.rb')
require Rails.root.join('spec', 'support', 'group_helper.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')
require 'faker'

class CollabNotificationWorkerTest < ActionView::TestCase
  include GroupHelper
  include TicketHelper
  include UsersHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = @account.users.first
    User.stubs(:current).returns(@user)
    @ticket = create_ticket(requester_id: @user.id)
    AwsWrapper::SqsV2.stubs(:send_message).returns(message_id: '1')
    @args = construct_args
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    AwsWrapper::SqsV2.unstub(:send_message)
    super
  end

  def construct_args
    {
      'mid' => Faker::Number.number(10),
      'mbody' => Faker::Lorem.paragraph,
      'metadata' => '{}',
      'm_ts' => 'Sample TS',
      'm_type' => '1',
      'top_members' => [],
      'ticket_display_id' => @ticket.display_id,
      'current_domain' => @account.host
    }
  end

  def stub_collab_settings
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(Account.current.users.first)
    Account.any_instance.stubs(:group_collab_enabled?).returns(true)
    Account.any_instance.stubs(:collab_settings).returns(Collab::Setting.new)
    Collaboration::Ticket.any_instance.stubs(:access_token).returns(Faker::Lorem.characters(10))
  end

  def un_stub_collab_settings
    Account.unstub(:current)
    User.unstub(:current)
    Account.any_instance.unstub(:group_collab_enabled?)
    Account.any_instance.unstub(:collab_settings)
    Collaboration::Ticket.any_instance.unstub(:access_token)
  end

  def test_collab_notification_worker_runs
    stub_collab_settings
    CollabNotificationWorker.new.perform(construct_args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_for_agent_notification
    stub_collab_settings
    @args['metadata'] = '{"hk_notify":[{"user_id":"' + @user.id.to_s + '","invite":true}]}'
    CollabNotificationWorker.new.perform(@args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_for_group_notification
    stub_collab_settings
    groups = [create_group(@account).id]
    @args['metadata'] = '{"hk_group_notify":' + groups.inspect + '}'
    CollabNotificationWorker.new.perform(@args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_with_follower_notification_with_group_collab_enabled
    stub_collab_settings
    new_group = create_group(@account)
    new_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], agent: 1, active: 1, role: 4, role_ids: [4], group_id: new_group.id)
    @args['metadata'] = '{"hk_group_notify":' + [new_group.id].inspect + ', "follower_notify":[{"follower_id":"' + new_agent.id.to_s + '"}]}'
    @args['top_members'] = '[{"member_id":"' + new_agent.agent.id.to_s + '"}]'
    CollabNotificationWorker.new.perform(@args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_with_group_collab_enabled_for_groups_without_agents
    stub_collab_settings
    new_group = create_group(@account)
    groups = [new_group.id]
    new_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], agent: 1, active: 1, role: 4, role_ids: [4])
    @args['metadata'] = '{"hk_notify":[{"user_id":"' + new_agent.id.to_s + '","invite":true}]}'
    CollabNotificationWorker.new.perform(@args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_with_group_collab_enabled_for_groups_with_agents
    stub_collab_settings
    new_group = create_group(@account)
    new_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], agent: 1, active: 1, role: 4, role_ids: [4], group_id: new_group.id)
    @args['metadata'] = '{"reply":{"r_id":"' + new_agent.id.to_s + '"},"hk_notify":[{"user_id":"' + @user.id.to_s + '","invite":true}], "hk_group_notify":' + [new_group.id].inspect + '}'
    CollabNotificationWorker.new.perform(@args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_having_groups_with_many_agents
    stub_collab_settings
    new_group = create_group(@account)
    agent_groups = []
    agent_ids = []
    agent_details = []
    35.times do
      new_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], agent: 1, active: 1, role: 4, role_ids: [4], group_id: new_group.id)
      agent_details << new_agent
      agent_ids << new_agent.id
      agent_groups << @ag_grp
    end
    @args['metadata'] = '{"hk_group_notify":' + [new_group.id].inspect + '}'
    CollabNotificationWorker.new.perform(@args)
    assert_equal 0, CollabNotificationWorker.jobs.size
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_raises_exception_for_invalid_metadata
    stub_collab_settings
    assert_raises JSON::ParserError do
      @args['metadata'] = Faker::Lorem.characters(10)
      CollabNotificationWorker.new.perform(@args)
    end
  ensure
    un_stub_collab_settings
  end

  def test_collab_notification_worker_raises_exception_for_invalid_top_members
    stub_collab_settings
    assert_raises JSON::ParserError do
      new_group = create_group(@account)
      new_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets], agent: 1, active: 1, role: 4, role_ids: [4], group_id: new_group.id)
      @args['metadata'] = '{"hk_group_notify":' + [new_group.id].inspect + ', "follower_notify":[{"follower_id":"' + new_agent.id.to_s + '"}]}'
      @args['top_members'] = Faker::Lorem.characters(10)
      CollabNotificationWorker.new.perform(@args)
    end
  ensure
    un_stub_collab_settings
  end
end

require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

Sidekiq::Testing.fake!

class ResetInternalGroupTest < ActionView::TestCase
  include GroupsTestHelper
  include CoreTicketsTestHelper
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    super
    before_all
  end

  def before_all
    if Account.current.nil?
      @user = create_test_account
      @user.make_current
    else
      @account = Account.current
    end
  end

  def teardown
    super
  end

  def test_reset_internal_group
    @account.stubs(:shared_ownership_enabled?).returns(true)
    internal_group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
    internal_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1, role_ids: [@account.roles.agent.first.id.to_s], agent: 1, group_id: internal_group.id)
    ticket_ids = []
    rand(1..10).times { ticket_ids << create_ticket(internal_group_id: internal_group.id, status_id: 2).id }
    Helpdesk::ResetInternalGroup.new.perform(internal_group_id: internal_group.id, status_id: 2)
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.internal_group_id.nil?
      assert tkt.internal_agent_id.nil?
    end
  ensure
    @account.unstub(:shared_ownership_enabled?)
  end

  def test_reset_internal_group_with_exception
    @account.stubs(:shared_ownership_enabled?).returns(true)
    internal_group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
    internal_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1, role_ids: [@account.roles.agent.first.id.to_s], agent: 1, group_id: internal_group.id)
    ticket_ids = []
    rand(1..10).times { ticket_ids << create_ticket(internal_group_id: internal_group.id, status_id: 2).id }
    Account.any_instance.stubs(:tickets).raises(RuntimeError)
    assert_raises(RuntimeError) do
      Helpdesk::ResetInternalGroup.new.perform(internal_group_id: internal_group.id, status_id: 2)
    end
    Account.any_instance.unstub(:tickets)
  ensure
    @account.unstub(:shared_ownership_enabled?)
  end
end

require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('spec', 'support', 'group_helper.rb')
require Rails.root.join('spec', 'support', 'ticket_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'archive_ticket_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'dashboard_object.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'widget_object.rb')

Sidekiq::Testing.fake!
class ResetGroupTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include GroupHelper
  include TicketHelper
  include ArchiveTicketTestHelper
  include CustomDashboardTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def dashboard_list
    @@dashboard_list ||= []
  end

  def update_dashboard_list(dashboard_object)
    self.dashboard_list << dashboard_object
  end

  def test_reset_group
    group = create_group @account
    ticket_ids = []
    rand(1..5).times { ticket_ids << create_ticket(group).id }
    Helpdesk::ResetGroup.new.perform(group_id: group.id, reason: { delete_group: group.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.group_id.nil?
    end
  end

  def test_reset_group_with_shared_ownership_enabled
    @account.stubs(:shared_ownership_enabled?).returns(true)
    internal_group = create_group @account
    ticket_ids = []
    rand(1..5).times { ticket_ids << create_ticket(internal_group).id }
    Helpdesk::ResetGroup.new.perform(internal_group_id: internal_group.id, reason: { delete_internal_group: internal_group.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.internal_group_id.nil?
      assert tkt.internal_agent_id.nil?
    end
  ensure
    @account.unstub(:shared_ownership_enabled?)
  end

  def test_pusblish_tickets_with_archive_tickets_included
    enable_archive_tickets do
      group = create_group @account
      ticket_ids = []
      rand(1..5).times { ticket_ids << create_ticket(group).id }
      Helpdesk::ResetGroup.new.perform(group_id: group.id, reason: { delete_group: group.id })
      @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
        assert tkt.group_id.nil?
      end
    end
  end

  def test_reset_group_with_exception
    group = create_group @account
    ticket_ids = []
    rand(1..5).times { ticket_ids << create_ticket(group).id }
    Account.any_instance.stubs(:tickets).raises(RuntimeError)
    assert_nothing_raised do
      Helpdesk::ResetGroup.new.perform(group_id: group.id, reason: { delete_group: group.id })
    end
    Account.any_instance.unstub(:tickets)
  end
  # handle_dashboards_widgets needs to be covered yet #
end

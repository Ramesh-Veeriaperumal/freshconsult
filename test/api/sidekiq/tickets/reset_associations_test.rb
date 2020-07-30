require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'conversations_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class ResetAssociationsTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include TestCaseMethods
  include ControllerTestHelper
  include ConversationsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
    Tickets::ResetAssociations.jobs.clear
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_reset_associations_for_parent_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      associates = @parent_ticket.associates
      "CentralPublishWorker::#{Account.current.subscription.state.titleize}TicketWorker".constantize.jobs.clear
      Tickets::ResetAssociations.new.perform(ticket_ids: [@parent_ticket.display_id])
      job = "CentralPublishWorker::#{Account.current.subscription.state.titleize}TicketWorker".constantize.jobs.last
      @parent_ticket.reload
      @child_ticket.reload
      assert_equal @parent_ticket.association_type, nil
      assert_equal @child_ticket.association_type, nil
      assert_equal job['args'][1]['misc_changes'], 'association_parent_unlink_all' => associates
    end
  end

  def test_reset_associations_for_child_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      Tickets::ResetAssociations.new.perform(ticket_ids: [@child_ticket.display_id])
      @child_ticket.reload
      assert_equal @child_ticket.association_type, nil
      assert_equal @child_ticket.associates_rdb, nil
    end
  end

  def test_reset_associations_for_tracker_ticket
    enable_adv_ticketing([:link_tickets]) do
      @agent = get_admin if @agent.nil?
      create_linked_tickets
      create_broadcast_note(@tracker_id)
      Tickets::ResetAssociations.new.perform(ticket_ids: [@tracker_id])
      tracker_ticket = @account.tickets.find_by_display_id(@tracker_id)
      assert_equal tracker_ticket.associates.count, 0
      assert_equal tracker_ticket.notes.broadcast_notes.count, 0
    end
  end

  def test_reset_associations_for_related_ticket
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      Tickets::ResetAssociations.new.perform(ticket_ids: [@ticket_id])
      related_ticket = @account.tickets.find_by_display_id(@ticket_id)
      assert_equal related_ticket.association_type, nil
      assert_equal related_ticket.associates_rdb, nil
    end
  end

  def test_reset_associations_with_disable_link_tickets
    enable_adv_ticketing([:link_tickets]) do
      link_tickets_old =  @account.tickets.where(association_type: [3,4])
      create_linked_tickets
      Tickets::ResetAssociations.new.perform(link_feature_disable: true)
      link_tickets = @account.tickets.where(association_type: [3,4])
      assert_equal link_tickets.count, link_tickets_old.count
    end
  end

  def test_reset_associations_with_disable_parent_child
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      Tickets::ResetAssociations.new.perform(parent_child_feature_disable: true)
      parent_child_tickets = @account.tickets.where(association_type: [1,2])
      service_task_type = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE

      service_tasks_associates_rdb = parent_child_tickets.map do |ticket|
        ticket.associates_rdb if ticket.ticket_type == service_task_type
      end
      parent_child_tickets.reject! do |ticket|
        ticket.ticket_type == service_task_type || service_tasks_associates_rdb.include?(ticket.display_id)
      end

      assert_equal parent_child_tickets.size, 0
    end
  end

  def test_reset_associations_with_exception
    assert_raises(RuntimeError) do
      create_parent_child_tickets
      create_linked_tickets
      ticket_ids = [@parent_ticket.display_id, @child_ticket.display_id, @tracker_id, @ticket_id]
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      Tickets::ResetAssociations.new.perform(ticket_ids: ticket_ids)
      Account.any_instance.unstub(:tickets)
    end
  end

  def test_reset_association_with_service_tasks_child
    service_task_type = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE

    enable_adv_ticketing([:field_service_management]) do
      perform_fsm_operations
      fsm_ticket = create_service_task_ticket

      child_tickets_before = @account.tickets.where(association_type: [2])
      service_task_count_before = child_tickets_before.select { |t| t.ticket_type == service_task_type }.count
      Tickets::ResetAssociations.new.perform(parent_child_feature_disable: true)
      child_tickets_after = @account.tickets.where(association_type: [2])
      service_task_count_after = child_tickets_after.select { |t| t.ticket_type == service_task_type }.count

      assert_equal service_task_count_before, service_task_count_after
    end
  end

  def test_reset_association_with_service_tasks_parent
    service_task_type = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE

    enable_adv_ticketing([:field_service_management]) do
      perform_fsm_operations
      fsm_ticket = create_service_task_ticket

      parent_tickets_before = @account.tickets.where(association_type: [1])
      parent_tickets_count_before = parent_tickets_before.select do |parent_ticket|
        subsidiary_tickets = parent_ticket.associated_subsidiary_tickets('assoc_parent')
        subsidiary_tickets.any? { |t| t.ticket_type == service_task_type }
      end.count

      Tickets::ResetAssociations.new.perform(parent_child_feature_disable: true)

      parent_tickets_after = @account.tickets.where(association_type: [1])
      parent_tickets_count_after = parent_tickets_after.select do |parent_ticket|
        subsidiary_tickets = parent_ticket.associated_subsidiary_tickets('assoc_parent')
        subsidiary_tickets.any? { |t| t.ticket_type == service_task_type }
      end.count

      assert_equal parent_tickets_count_before, parent_tickets_count_after
    end
  end
end

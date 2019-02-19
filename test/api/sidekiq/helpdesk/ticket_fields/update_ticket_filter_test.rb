require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'query_hash_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'dashboard_object.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'widget_object.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class SidekiqUpdateTicketFilterTest < ActionView::TestCase
  include CustomDashboardTestHelper
  include TicketFieldsTestHelper
  include QueryHashHelper
  include AccountTestHelper
  include UsersTestHelper

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

  def test_barchart_categorized_by_field_deleted
    field = create_custom_field_dropdown('test_custom_dropdown_ticket_filter_test_1', ['Option 1', 'Option 2', 'fdvfd'], '15')
    options = { ticket_filter_id: 'unresolved', representation: 0, categorised_by: field.id }
    barchart_dashboard = create_dashboard_with_widgets(nil, 1, 1, [options])
    Sidekiq::Testing.inline! do
      Helpdesk::TicketFields::UpdateTicketFilter.new.perform(field_id: field.id)
    end
    assert_equal barchart_dashboard.widgets.first.active, false
  ensure
    field.destroy
    barchart_dashboard.destroy
  end

  def test_update_ticket_filters_by_field_deleted
    @custom_field = create_custom_field_dropdown('test_custom_dropdown_ticket_filter_test_2', ['Option 1', 'Option 2', 'fdvfd'], '16')
    filter = create_filter(@custom_field)
    Sidekiq::Testing.inline! do
      Helpdesk::TicketFields::UpdateTicketFilter.new.perform(field_id: @custom_field.id, conditions: [{ 'condition_key' => 'flexifields.ffs_16' }])
    end
    assert_equal filter.query_hash.map { |k| k['condition'] }.include?('flexifields.ffs_16'), false
  ensure
    filter.destroy
    @custom_field.destroy
  end

  def test_update_ticket_filters_by_field_modified
    @custom_field = create_custom_field_dropdown('test_custom_dropdown_ticket_filter_test_2', ['Option 1', 'Option 2', 'fdvfd'], '16')
    filter = create_filter(@custom_field)
    Sidekiq::Testing.inline! do
      Helpdesk::TicketFields::UpdateTicketFilter.new.perform(field_id: @custom_field.id, conditions: [{ 'condition_key' => 'flexifields.ffs_16', 'replace_key' => 'flexifields.ffs_15' }])
    end
    assert_equal filter.query_hash.map { |k| k['condition'] }.include?('flexifields.ffs_16'), false
    assert_equal filter.query_hash.map { |k| k['condition'] }.include?('flexifields.ffs_15'), true
  ensure
    filter.destroy
    @custom_field.destroy
  end

  def test_update_ticket_filter_with_exception
    field = create_custom_field_dropdown('test_custom_dropdown_ticket_filter_test_1', ['Option 1', 'Option 2', 'fdvfd'], '15')
    options = { ticket_filter_id: 'unresolved', representation: 0, categorised_by: field.id }
    barchart_dashboard = create_dashboard_with_widgets(nil, 1, 1, [options])
    Account.any_instance.stubs(:ticket_filters).raises(RuntimeError)
    assert_raises(RuntimeError) do
      Helpdesk::TicketFields::UpdateTicketFilter.new.perform(field_id: field.id)
    end
    Account.any_instance.unstub(:ticket_filters)
  ensure
    field.destroy
    barchart_dashboard.destroy
  end
end

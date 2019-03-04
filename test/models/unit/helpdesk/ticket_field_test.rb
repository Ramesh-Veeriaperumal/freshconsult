require_relative '../../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class TicketFieldTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant

  def test_duplicate_ticket_status
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'open', 'open', last_position_id))
    assert_equal last_position_id, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end

  def test_translate_key_value
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'support', 'support',last_position_id))
    assert_equal last_position_id+1, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end

  def test_change_status_customer_name
    locale = I18n.locale
    I18n.locale = 'de'
    prev_status = @account.ticket_statuses.where(status_id: 2).first
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'open', 'Edited', prev_status.position))
    curr_status = @account.ticket_statuses.where(status_id: 2).first
    assert_not_equal prev_status.customer_display_name, curr_status.customer_display_name
    ensure
      I18n.locale = locale
  end

  def test_default_ticket_types
    Account.stubs(:current).returns(Account.first)
    perform_fsm_operations
    field = Account.current.ticket_fields.find_by_field_type("default_ticket_type")
    record = Account.current.ticket_types_from_cache.find{ |x| x.value == SERVICE_TASK_TYPE}
    service_task_data = [record.value, record.value, {"data-id"=>record.id}]
    data = field.html_unescaped_choices
    refute data.include?(service_task_data)
  ensure
    cleanup_fsm
    Account.unstub(:current)
  end

  def test_default_group
    Account.stubs(:current).returns(Account.first)
    perform_fsm_operations
    field = Account.current.ticket_fields.find_by_field_type("default_group")
    records = Account.current.groups_from_cache.select{ |x| x.group_type == GroupType.group_type_id(GroupConstants::SUPPORT_GROUP_NAME)}
    output_data = field.html_unescaped_choices
    assert_equal records.count,output_data.count
  ensure
    cleanup_fsm
    Account.unstub(:current)
  end

end
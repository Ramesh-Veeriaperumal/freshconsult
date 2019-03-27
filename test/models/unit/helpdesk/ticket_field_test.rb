require_relative '../../test_helper'
require_relative '../../../test_helper'
require_relative '../../helpers/tickets_test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class TicketFieldTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant
  include TicketsTestHelper

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

  def test_default_field_order
    expected_output = TicketConstants::DEFAULT_FIELDS_ORDER
    default_field_order = Helpdesk::TicketField.default_field_order
    assert_equal(expected_output, default_field_order)
  end

  def test_html_unescaped_choices
    Account.stubs(:current).returns(Account.first)
    ticket = create_ticket
    group = Account.current.groups.first
    group.agent_groups.create(user_id: ticket.requester.id)
    ticket.group_id = group.id
    company = Account.current.companies.create(name: 'test_company')
    ticket.company = company
    ticket.save

    priority_field = Account.current.ticket_fields.find_by_field_type('default_priority')
    expected_output = TicketConstants.priority_names
    html_unescaped_choices = priority_field.html_unescaped_choices
    assert_equal(expected_output, html_unescaped_choices)

    source_field = Account.current.ticket_fields.find_by_field_type('default_source')
    expected_output = TicketConstants.source_names
    html_unescaped_choices = source_field.html_unescaped_choices
    assert_equal(expected_output, html_unescaped_choices)

    status_field = Account.current.ticket_fields.find_by_field_type('default_status')
    expected_output = [['Low', 1], ['Medium', 2], ['High', 3], ['Urgent', 4]]
    html_unescaped_choices = priority_field.html_unescaped_choices
    assert_equal(expected_output, html_unescaped_choices)

    agent_field = Account.current.ticket_fields.find_by_field_type('default_agent')
    agent_ids = []
    AgentGroup.all.each do |agent|
      agent_ids << agent.user_id if agent.account_id == Account.current.id && agent.group_id == group.id
    end
    expected_output = []
    agent_ids.uniq.each do |id|
      user = User.find_by_id id
      expected_output << [user.name, user.id] unless user.deleted
    end
    sorted_expected_output = expected_output.sort_by { |a| a[0] }
    html_unescaped_choices = agent_field.html_unescaped_choices(ticket)
    assert_equal(sorted_expected_output, html_unescaped_choices)

    company_field = Account.current.ticket_fields.find_by_field_type('default_company')
    expected_output = [[company.name, company.id]]
    html_unescaped_choices = company_field.html_unescaped_choices(ticket)
    assert_equal(expected_output, html_unescaped_choices)

    subject_field = Account.current.ticket_fields.find_by_field_type('default_subject')
    expected_output = []
    html_unescaped_choices = subject_field.html_unescaped_choices
    assert_equal(expected_output, html_unescaped_choices)
  end

  def test_status_choices
    Account.stubs(:current).returns(Account.first)
    status_field = Account.current.ticket_fields.find_by_field_type('default_status')
    all_status_choices = status_field.all_status_choices('name')
    expected_output = []
    Helpdesk::TicketStatus.all.each do |status|
      expected_output << [status.name, status.status_id]
    end
    assert_equal(expected_output, all_status_choices)
    visible_status_choices = status_field.visible_status_choices('name')
    expected_output = []
    Helpdesk::TicketStatus.all.each do |status|
      expected_output << [status.name, status.status_id]
    end
    assert_equal(expected_output, visible_status_choices)
  end

  def test_custom_dropdown
    Account.stubs(:current).returns(Account.first)
    custom_dropdown_field = create_custom_field_dropdown(name = 'test_custom_dropdown', choices = ['Choice 1', 'Choice 2', 'Choice 3'])
    choice1 = Account.current.picklist_values.find_by_value('Choice 1')
    choice2 = Account.current.picklist_values.find_by_value('Choice 2')
    choice3 = Account.current.picklist_values.find_by_value('Choice 3')
    choices_when_admin_pg_false = custom_dropdown_field.choices(ticket = nil, admin_pg = false)
    expected_output_when_admin_pg_false = [[choice1.value, choice1.value], [choice2.value, choice2.value], [choice3.value, choice3.value]]
    assert_equal(choices_when_admin_pg_false, expected_output_when_admin_pg_false)

    choices_when_admin_pg_true = custom_dropdown_field.choices(ticket = nil, admin_pg = true)
    expected_output_when_admin_pg_true = [[choice1.value, choice1.value, choice1.id], [choice2.value, choice2.value, choice2.id], [choice3.value, choice3.value, choice3.id]]
    assert_equal(choices_when_admin_pg_true, expected_output_when_admin_pg_true)

    html_unescaped_choices = custom_dropdown_field.html_unescaped_choices
    expected_output = [[choice1.value, choice1.value, { 'data-id' => choice1.id }], [choice2.value, choice2.value, { 'data-id' => choice2.id }], [choice3.value, choice3.value, { 'data-id' => choice3.id }]]
    assert_equal(html_unescaped_choices, expected_output)

    flexifield_name = custom_dropdown_field.flexifield_name
    expected_output = custom_dropdown_field.column_name
    assert_equal(flexifield_name, expected_output)

    as_json = custom_dropdown_field.as_json
    assert_equal(as_json['ticket_field'][:nested_ticket_fields], [])
    assert_equal(as_json['ticket_field'].include?(:account_id), false)
    assert_equal(as_json['ticket_field'].include?(:choices), true)
    assert_equal(as_json['ticket_field'].include?(:nested_choices), false)

    dropdown_choices_with_picklist_id = custom_dropdown_field.dropdown_choices_with_picklist_id
    expected_output = [[nil, nil], [nil, nil], [nil, nil]]
    assert_equal(dropdown_choices_with_picklist_id, expected_output)

    dropdown_choices_with_id = custom_dropdown_field.dropdown_choices_with_id
    expected_output = [[choice1.id, choice1.value], [choice2.id, choice2.value], [choice3.id, choice3.value]]
    assert_equal(dropdown_choices_with_id, expected_output)

    dropdown_selected = custom_dropdown_field.dropdown_selected(custom_dropdown_field.html_unescaped_choices, choice1.value)
    selected_value = choice1.value
    assert_equal(dropdown_selected, selected_value)

    picklist_values_by_id = custom_dropdown_field.picklist_values_by_id
    expected_output = { nil => choice3.value }
    assert_equal(picklist_values_by_id, expected_output)

    picklist_ids_by_value = custom_dropdown_field.picklist_ids_by_value
    expected_output = { choice1.value.downcase => nil, choice2.value.downcase => nil, choice3.value.downcase => nil }
    assert_equal(picklist_ids_by_value, expected_output)

    to_xml = custom_dropdown_field.to_xml
    doc = Nokogiri::XML to_xml
    xml_to_hash = doc.to_hash
    assert_equal(xml_to_hash['helpdesk-ticket-field']['label']['__content__'], 'test_custom_dropdown')
    assert_equal(xml_to_hash['helpdesk-ticket-field']['choices']['option'].first['value']['__content__'], 'Choice 1')
  end

  def test_nested_field
    nested_field_parent = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
    nested_child_fields = nested_field_parent.child_levels
    nestedfieldlevel2 = nested_child_fields.first
    nestedfieldlevel3 = nested_child_fields.second

    parentoflevel3 = nestedfieldlevel3.parent_field
    assert_equal(parentoflevel3, nestedfieldlevel2)

    parentoflevel2 = nestedfieldlevel2.parent_field
    assert_equal(parentoflevel2, nested_field_parent)

    is_child = nestedfieldlevel2.child_nested_field?
    assert_equal(true, is_child)

    is_parent = nested_field_parent.parent_nested_field?
    assert_equal(true, is_parent)

    country1 = Account.current.picklist_values.find_by_value('Australia')
    country2 = Account.current.picklist_values.find_by_value('USA')
    state1 = Account.current.picklist_values.find_by_value('New South Wales')
    state2 = Account.current.picklist_values.find_by_value('Queensland')
    state3 = Account.current.picklist_values.find_by_value('California')
    state4 = Account.current.picklist_values.find_by_value('Texas')
    city1 = Account.current.picklist_values.find_by_value('Sydney')
    city2 = Account.current.picklist_values.find_by_value('Brisbane')
    city3 = Account.current.picklist_values.find_by_value('Burlingame')
    city4 = Account.current.picklist_values.find_by_value('Los Angeles')
    city5 = Account.current.picklist_values.find_by_value('Houston')
    city6 = Account.current.picklist_values.find_by_value('Dallas')

    choices = nested_field_parent.choices
    expected_output = [[country1.value, country1.value], [country2.value, country2.value]]
    assert_equal(choices, expected_output)

    nested_choices = nested_field_parent.nested_choices
    expected_output = [[country1.value, country1.value, [[state1.value, state1.value, [[city1.value, city1.value]]], [state2.value, state2.value, [[city2.value, city2.value]]]]], [country2.value, country2.value, [[state3.value, state3.value, [[city3.value, city3.value], [city4.value, city4.value]]], [state4.value, state4.value, [[city5.value, city5.value], [city6.value, city6.value]]]]]]
    assert_equal(nested_choices, expected_output)

    nested_choices_with_id = nested_field_parent.nested_choices_with_id
    expected_output = [[country1.id, country1.value, [[state1.id, state1.value, [[city1.id, city1.value]]], [state2.id, state2.value, [[city2.id, city2.value]]]]], [country2.id, country2.value, [[state3.id, state3.value, [[city3.id, city3.value], [city4.id, city4.value]]], [state4.id, state4.value, [[city5.id, city5.value], [city6.id, city6.value]]]]]]
    assert_equal(nested_choices_with_id, expected_output)

    nested_special_case = [['none', 'none']]
    nested_choices_with_special_case = nested_field_parent.nested_choices_with_special_case nested_special_case
    assert_equal(nested_choices_with_special_case.first.first, 'none')

    html_unescaped_choices = nested_field_parent.html_unescaped_choices
    expected_output = [[country1.value, country1.value], [country2.value, country2.value]]
    assert_equal(html_unescaped_choices, expected_output)

    levels = nested_field_parent.levels
    id1 = Helpdesk::NestedTicketField.find_by_label('test_custom_state').id
    id2 = Helpdesk::NestedTicketField.find_by_label('test_custom_city').id
    expected_output = [{ id: id1, label: 'test_custom_state', label_in_portal: 'test_custom_state', description: nil, level: 2, position: 1, type: 'dropdown' }, { id: id2, label: 'test_custom_city', label_in_portal: 'test_custom_city', description: nil, level: 3, position: 1, type: 'dropdown' }]
    assert_equal(levels, expected_output)

    to_xml = nested_field_parent.to_xml
    doc = Nokogiri::XML to_xml
    xml_to_hash = doc.to_hash
    assert_equal(xml_to_hash['helpdesk-ticket-field']['label']['__content__'], 'test_custom_country')
    assert_equal(xml_to_hash['helpdesk-ticket-field']['nested_ticket_fields']['nested_ticket_field'][0]['label']['__content__'], 'test_custom_state')
    assert_equal(xml_to_hash['helpdesk-ticket-field']['choices']['option'].first['value']['__content__'], country1.value)

    as_json = nested_field_parent.as_json
    assert_equal(as_json['ticket_field'].include?(:nested_ticket_fields), true)
    assert_equal(as_json['ticket_field'].include?(:account_id), false)
    assert_equal(as_json['ticket_field'].include?(:choices), false)
    assert_equal(as_json['ticket_field'].include?(:nested_choices), true)

    picklistvaluesbyidlevel2 = nestedfieldlevel2.picklist_values_by_id
    expected_output = { nil => state4.value }
    assert_equal(picklistvaluesbyidlevel2, expected_output)

    picklistvaluesbyidlevel3 = nestedfieldlevel3.picklist_values_by_id
    expected_output = { nil => city6.value }
    assert_equal(picklistvaluesbyidlevel3, expected_output)

    picklistidsbyvaluelevel2 = nestedfieldlevel2.picklist_ids_by_value
    expected_output = { state1.value.downcase => { country1.value => nil }, state2.value.downcase => { country1.value => nil }, state3.value.downcase => { country2.value => nil }, state4.value.downcase => { country2.value => nil } }
    assert_equal(picklistidsbyvaluelevel2, expected_output)

    picklistidsbyvaluelevel3 = nestedfieldlevel3.picklist_ids_by_value
    expected_output = { city1.value.downcase => { state1.value.downcase => { country1.value => nil } }, city2.value.downcase => { state2.value.downcase => { country1.value => nil } }, city3.value.downcase => { state3.value.downcase => { country2.value => nil } }, city4.value.downcase => { state3.value.downcase => { country2.value => nil } }, city5.value.downcase => { state4.value.downcase => { country2.value => nil } }, city6.value.downcase => { state4.value.downcase => { country2.value => nil } } }
    assert_equal(picklistidsbyvaluelevel3, expected_output)
  end
end
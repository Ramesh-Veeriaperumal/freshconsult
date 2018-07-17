['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module TicketFieldsSandboxHelper
  include ::TicketFieldsTestHelper
  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph date).freeze
  TICKET_FIELD_MODEL_NAME = "Helpdesk::TicketField"
  ACTIONS = ['delete', 'update', 'create']

  def ticket_fields_data(account)
    all_ticket_fields_data = []
    ACTIONS.each do |action|
      all_ticket_fields_data << send("#{action}_ticket_fields_data", account)
    end
    all_ticket_fields_data.flatten
  end

  def create_ticket_fields_data(account)
    ticket_fields_data = []
    # basic dropdown field
    dropdown_field = create_custom_field_dropdown
    # basic custom fields
    CUSTOM_FIELDS.each do |custom_field|
      ticket_fields_data << Hash[create_custom_field("test_custom_#{custom_field}", custom_field).attributes].merge('model' => TICKET_FIELD_MODEL_NAME, 'action' => 'added')
    end
    # section field
    dd_field_with_sections = create_custom_field_dropdown_with_sections
    sections = [ { title: Faker::Name.name, value_mapping: %w(Question Problem), ticket_fields: %w(test_custom_number test_custom_date) },
                        { title: Faker::Name.name, value_mapping: ['Incident'], ticket_fields: %w(test_custom_paragraph test_custom_dropdown) } ]
    create_section_fields(dd_field_with_sections.id, sections)
    # nested_field
    nested_field = create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    # populate_ticket_fields_data
    ticket_fields_data << populate_ticket_fields_data(account, dropdown_field, dd_field_with_sections, nested_field)
    ticket_fields_data.flatten
  end

  def update_ticket_fields_data(account)
    ticket_field = account.ticket_fields.last
    return [] unless ticket_field
    ticket_field.label = 'field_label_modified'
    data = ticket_field.changes.clone
    ticket_field.save
    Hash[data.map { |k, v| [k, v[1]] }].merge("id" => ticket_field.id).merge("model" => TICKET_FIELD_MODEL_NAME, "action" => "modified")
  end

  def delete_ticket_fields_data(account)
    ticket_field = account.ticket_fields.last
    return [] unless ticket_field
    ticket_field.destroy
    Hash[ticket_field.attributes].merge("model" => TICKET_FIELD_MODEL_NAME, "action" => "deleted")
  end

  def populate_ticket_fields_data(account, dropdown_field, dd_field_with_sections, nested_field)
    ticket_fields_data = []
    # parent field data
    ticket_fields_data << Hash[dropdown_field.attributes].merge('model' => TICKET_FIELD_MODEL_NAME, 'action' => 'added')
    ticket_fields_data << Hash[dd_field_with_sections.attributes].merge('model' => TICKET_FIELD_MODEL_NAME, 'action' => 'added')
    ticket_fields_data << Hash[nested_field.attributes].merge('model' => TICKET_FIELD_MODEL_NAME, 'action' => 'added')
    # sections data
    ticket_fields_data << dd_field_with_sections.picklist_values.map { |object| Hash[object.attributes].merge('model' => object.class.name, 'action' => 'added') }
    account.section_fields.where(:parent_ticket_field_id => dd_field_with_sections.id).each do |section_field|
      section = section_field.section
      ticket_fields_data << Hash[section.attributes].merge('model' => section.class.name, 'action' => 'added')
      ticket_fields_data << section.section_picklist_mappings.map { |object| Hash[object.attributes].merge('model' => object.class.name, 'action' => 'added') }
    end
    # dropdown fields picklist data
    ticket_fields_data << dropdown_field.picklist_values.map { |object| Hash[object.attributes].merge('model' => object.class.name, 'action' => 'added') }
    # nested fields data
    ticket_fields_data << nested_field.nested_ticket_fields.map { |object| Hash[object.attributes].merge('model' => object.class.name, 'action' => 'added') }
    ticket_fields_data << nested_field.picklist_values.map { |object| Hash[object.attributes].merge('model' => object.class.name, 'action' => 'added') }
    ticket_fields_data
  end
end

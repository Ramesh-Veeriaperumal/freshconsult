module Helpers::ContactFieldsTestHelper
  include ContactFieldsHelper
  # Patterns
  def contact_field_pattern_without_choices(expected_output = {}, contact_field)
    default_contact_field = contact_field.column_name == 'default'

    {
      default: expected_output[:default] || default_contact_field,
      customers_can_edit: expected_output[:customers_can_edit] || contact_field.editable_in_portal,
      editable_in_signup: expected_output[:editable_in_signup] || contact_field.editable_in_signup,
      type: expected_output[:type] || contact_field.field_type.to_s,
      id: Fixnum,
      label: expected_output[:label] || contact_field.label,
      label_for_customers: expected_output[:label_for_customers] || contact_field.label_in_portal,
      name: expected_output[:name] || (default_contact_field ? contact_field.name : CustomFieldDecorator.display_name(contact_field.name)),
      position: expected_output[:position] || contact_field.position,
      required_for_agents: expected_output[:required_for_agents] || contact_field.required_for_agent,
      required_for_customers: expected_output[:required_for_customers] || contact_field.required_in_portal,
      displayed_for_customers: expected_output[:displayed_for_customers] || contact_field.visible_in_portal,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def contact_field_pattern(expected_output = {}, contact_field)
    result = contact_field_pattern_without_choices(expected_output, contact_field)
    unless contact_field.choices.blank?
      result.merge!(choices: contact_field_choices(contact_field))
    end
    result
  end

  # Helpers
  def contact_field_choices(contact_field)
    case contact_field.field_type.to_s
    when 'default_language', 'default_time_zone'
      contact_field.choices.map { |x| x.values.reverse }.to_h
    when 'custom_dropdown' # not_tested
      contact_field.choices.map { |x| x[:value] }
    else
      []
    end
  end
end

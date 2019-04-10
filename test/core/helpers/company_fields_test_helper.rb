module CompanyFieldsTestHelper

  def create_custom_company_field options
    CompanyField.create_field options
  end

  def company_params(options = {})
    {
      field_options: options[:field_options] || nil,
      type: options[:type], 
      field_type: options[:field_type], 
      label: options[:label], 
      required_for_agent: options[:required_for_agent] || false, 
      id: nil,
      custom_field_choices_attributes: options[:custom_field_choices_attributes] || [],
      position: rand(15..1000)
    }
  end

  def company_field_publish_pattern(custom_field)
    {
      id: custom_field.id,
      account_id: custom_field.account_id,
      form_id: custom_field.company_form_id,
      name: custom_field.name,
      column_name: custom_field.column_name,
      label: custom_field.label,
      field_type: custom_field.field_type,
      position: custom_field.position,
      deleted: custom_field.deleted,
      required_for_agent: custom_field.required_for_agent,
      field_options: custom_field.field_options,
      created_at: custom_field.created_at.try(:utc).try(:iso8601),
      updated_at: custom_field.updated_at.try(:utc).try(:iso8601)
    }
  end

  def company_field_choice_publish_pattern(cf_choice)
    {
      id: cf_choice.id,
      account_id: cf_choice.account_id,
      company_field_id: cf_choice.company_field_id,
      value: cf_choice.value,
      position: cf_choice.position,
      created_at: cf_choice.created_at.try(:utc).try(:iso8601),
      updated_at: cf_choice.updated_at.try(:utc).try(:iso8601)
    }
  end

  def model_changes_company_field_choice(old_value, new_value)
    {
      'value' => [old_value, new_value]
    }
  end

  def central_publish_company_field_choice_destroy_pattern(cf_choice)
    {
      id: cf_choice.id,
      company_field_id: cf_choice.company_field_id,
      account_id: cf_choice.account_id
    }
  end
end

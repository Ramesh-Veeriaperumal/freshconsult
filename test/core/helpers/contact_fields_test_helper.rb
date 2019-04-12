module ContactFieldsTestHelper
  def create_custom_contact_field options
    ContactField.create_field options
  end

  def cf_params options = {}
    {
     :field_options => options[:field_options] || nil,
     :type=> options[:type], 
     :field_type=> options[:field_type], 
     :label=> options[:label], 
     :label_in_portal=> options[:label_in_portal] || options[:label], 
     :required_for_agent=> options[:required_for_agent] || false, 
     :visible_in_portal=> options[:visible_in_portal] || true, 
     :editable_in_portal=> options[:editable_in_portal] || true, 
     :required_in_portal=> options[:required_in_portal] || false, 
     :editable_in_signup=> options[:editable_in_signup] || false,
     :id=>nil, :custom_field_choices_attributes => options[:custom_field_choices_attributes] || [], :position=>rand(15..1000)
   }
  end

  def create_contact_field(account)
    existing_fields_count = account.contact_form.fields.length
    contact_field = ContactField.new
    contact_field.name = Faker::Name.name
    contact_field.field_type = 'custom_text'
    contact_field.column_name = 'text'
    contact_field.label = Faker::Name.name
    contact_field.position = existing_fields_count + 1
    account.reload
    contact_field.contact_form_id = account.contact_form.id
    contact_field.save
    contact_field
  end

  def contact_field_publish_pattern(custom_field)
    {
      id: custom_field.id,
      account_id: custom_field.account_id,
      form_id: custom_field.contact_form_id,
      name: custom_field.name,
      column_name: custom_field.column_name,
      label: custom_field.label,
      label_in_portal: custom_field.label_in_portal,
      field_type: custom_field.field_type,
      position: custom_field.position,
      deleted: custom_field.deleted,
      required_for_agent: custom_field.required_for_agent,
      visible_in_portal: custom_field.visible_in_portal,
      editable_in_portal: custom_field.editable_in_portal,
      editable_in_signup: custom_field.editable_in_signup,
      required_in_portal: custom_field.required_in_portal,
      field_options: custom_field.field_options,
      created_at: custom_field.created_at.try(:utc).try(:iso8601),
      updated_at: custom_field.updated_at.try(:utc).try(:iso8601)
    }
  end

  def contact_field_choice_publish_pattern(cf_choice)
    {
      id: cf_choice.id,
      account_id: cf_choice.account_id,
      contact_field_id: cf_choice.contact_field_id,
      value: cf_choice.value,
      position: cf_choice.position,
      created_at: cf_choice.created_at.try(:utc).try(:iso8601),
      updated_at: cf_choice.updated_at.try(:utc).try(:iso8601)
    }
  end

  def model_changes_contact_field_choice(old_value, new_value)
    {
      'value' => [old_value, new_value]
    }
  end

  def central_publish_contact_field_choice_destroy_pattern(cf_choice)
    {
      id: cf_choice.id,
      contact_field_id: cf_choice.contact_field_id,
      account_id: cf_choice.account_id
    }
  end
end

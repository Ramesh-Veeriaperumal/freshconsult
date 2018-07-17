module ContactFormSandboxHelper
  MODEL_NAME = 'ContactField'
  ACTIONS = ['delete', 'update', 'create']

  def contact_form_data(account)
    all_contact_form_data = []
    ACTIONS.each do |action|
      all_contact_form_data << send("#{action}_contact_form_data", account)
    end
    all_contact_form_data.flatten
  end

  def create_contact_form_data(account)
    contact_field_data = []
    3.times do
      contact_field = create_contact_field(account)
      contact_field_data << contact_field.attributes.merge("model" => MODEL_NAME, "action" => "added")
    end
    return contact_field_data
  end

  def update_contact_form_data(account)
    account.reload
    contact_field = account.contact_form.contact_fields.last
    return [] unless contact_field
    contact_field.name = "modified_contact_field"
    changed_attr = contact_field.changes
    contact_field.save
    return [Hash[changed_attr.map {|k,v| [k,v[1]]}].merge("id"=> contact_field.id).merge("model" => MODEL_NAME, "action" => "modified")]
  end

  def delete_contact_form_data(account)
    contact_field = account.contact_form.contact_fields.last
    return [] unless contact_field
    contact_field.destroy
    return [contact_field.attributes.merge("model" => MODEL_NAME, "action" => "deleted")]
  end

  def create_contact_field (account, params = {})
    existing_fields_count = account.contact_form.fields.length
    contact_field = ContactField.new
    contact_field.name = Faker::Name.name
    contact_field.field_type = "custom_text"
    contact_field.column_name = "text"
    contact_field.label = Faker::Name.name
    contact_field.position = existing_fields_count + 1
    account.reload
    contact_field.contact_form_id = account.contact_form.id
    contact_field.save
    contact_field
  end

end
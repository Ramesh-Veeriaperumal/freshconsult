module CompanyFormSandboxHelper
  MODEL_NAME = 'CompanyField'
  ACTIONS = ['delete', 'update', 'create']

  def company_form_data(account)
    all_company_form_data = []
    ACTIONS.each do |action|
      all_company_form_data << send("#{action}_company_form_data", account)
    end
    all_company_form_data.flatten
  end

  def create_company_form_data(account)
    company_field_data = []
    3.times do
      company_field = create_company_field(account)
      company_field_data << company_field.attributes.merge("model" => MODEL_NAME, "action" => "added")
    end
    return company_field_data
  end

  def update_company_form_data(account)
    account.reload
    company_field = account.company_form.company_fields.last
    return [] unless company_field
    company_field.name = "modified_company_field"
    changed_attr = company_field.changes
    company_field.save
    return [Hash[changed_attr.map {|k,v| [k,v[1]]}].merge("id"=> company_field.id).merge("model" => MODEL_NAME, "action" => "modified")]
  end

  def delete_company_form_data(account)
    company_field = account.company_form.company_fields.last
    return [] unless company_field
    company_field.destroy
    return [company_field.attributes.merge("model" => MODEL_NAME, "action" => "deleted")]
  end

  def create_company_field (account)
    existing_fields_count = account.company_form.fields.length
    company_field = CompanyField.new
    company_field.name = Faker::Name.name
    company_field.field_type = "custom_text"
    company_field.column_name = "text"
    company_field.label = Faker::Name.name
    company_field.position = existing_fields_count + 1
    company_field.company_form_id = account.company_form.id
    company_field.save
    company_field
  end

end
module CompaniesHelper

  include ContactsCompaniesHelper

  def company_fields
    current_account.company_form.company_fields_from_cache
  end

  def render_as_list form_builder, field
    field_value = (field_value = @company.send(field.name)).blank? ? field.default_value : field_value
    if form_builder.nil? 
      show_field field,field_value
    else
      CustomFields::View::DomElement.new(form_builder, :company, :company_form, field, field.label, field.dom_type, 
            field.required_for_agent, true, field_value, field.dom_placeholder, field.bottom_note).construct
    end
  end

  def view_company_fields 
    reject_fields = [:default_name, :default_description, :default_note]
    view_company_fields = company_fields.reject do |item|
      field_value = (field_value = @company.send(item.name)).blank? ? item.default_value : field_value
      (reject_fields.include? item.field_type) || !field_value.present?
    end
  end

  def company_activities
    activities = @company_tickets
    activities = activities.take(10)
  end
end
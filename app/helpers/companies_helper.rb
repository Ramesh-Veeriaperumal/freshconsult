module CompaniesHelper

  include ContactsCompaniesHelper

  def company_fields
    current_account.company_form.company_fields
  end

  def render_as_list form_builder, field
    field_value = (field_value = @company.safe_send(field.name)).blank? ? field.default_value : field_value
    if form_builder.nil? 
      show_field field,field_value
    else
      bottom_note = form_company_bottom_note(field)
      CustomFields::View::DomElement.new(form_builder, :company, :company_form, field, field.label, field.dom_type, 
            field.required_for_agent, true, field_value, field.dom_placeholder, bottom_note).construct
    end
  end

  def view_company_fields 
    reject_fields = [:default_name, :default_description, :default_note]
    view_company_fields = company_fields.reject do |item|
      field_value = (field_value = @company.safe_send(item.name)).blank? ? item.default_value : field_value
      (reject_fields.include? item.field_type) || !field_value.present?
    end
  end

  def company_activities
    activities = @company_tickets
    activities = activities.take(10)
  end

  private

  def form_company_bottom_note field
    if current_account.restricted_helpdesk? && (field.field_type == :default_domains)
      return I18n.t("company.info14")
    end
    field.bottom_note
  end
  
  def company_count
    count = current_account.companies.size
    "<span class='company-list-count' data-company-count='#{count}'></span>".html_safe
  end
end

module Support::ProfilesHelper

  include UserEmailsHelper

  def customer_visible_fields
    current_account.contact_form.customer_visible_contact_fields
  end
  
  def render_as_list form_builder, field
    field_value = (field_value = @profile.send(field.name)).blank? ? field.default_value : field_value
    return if (!field.editable_in_portal && field_value.blank? )
    field_value = I18n.name_for_locale(field_value) if field.field_type == :default_language && !field.editable_in_portal
    UserEmailsHelper::FreshdeskDomElement.new(form_builder, :user, :profile, field, field.label_in_portal, 
      field.dom_type, field.required_in_portal, field.editable_in_portal, field_value,'','', {:account => current_account}).construct
  end
end

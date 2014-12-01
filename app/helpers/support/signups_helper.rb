module Support::SignupsHelper

  def customer_signup_fields
    current_account.contact_form.customer_signup_contact_fields
  end

  def render_as_list form_builder, field
    field_value = (field_value = @user.send(field.name)).blank? ? field.default_value : field_value
    required = (field.field_type == 'default_email') ? true : field.required_in_portal
    CustomFields::View::DomElement.new(form_builder, :user, :signup, field, field.label_in_portal, field.dom_type,
                      required, true, field_value).construct
  end

end
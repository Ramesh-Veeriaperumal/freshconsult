module HelpWidgetConstants
  HELP_WIDGET_FIELDS = %w(id product_id name settings).freeze
  VALIDATION_CLASS = 'HelpWidgetValidation'.freeze
  DELEGATOR_CLASS = 'HelpWidgetDelegator'.freeze
  WHITELISTED_SETTINGS = %w(message button_text components contact_form appearance).freeze
  WHITELISTED_COMPONENTS = %w(contact_form suggestions).freeze
  WHITELISTED_CONTACT_FORM = %w(form_type form_title form_submit_message form_button_text screenshot attach_file captcha secret).freeze
  WHITELISTED_APPEARANCE = %w(position offset_from_bottom offset_from_left offset_from_right height theme_color button_color ).freeze
  COMPONENTS = WHITELISTED_COMPONENTS
  CONTACT_FORM = WHITELISTED_CONTACT_FORM
  SETTINGS_FIELDS = WHITELISTED_SETTINGS
  APPEARANCE = WHITELISTED_APPEARANCE
  CREATE_FIELDS = %w(product_id settings).freeze
  TEXT_FIELDS_MAX_LENGTH = 60
  BUTTON_TEXT_LENGTH = 40

  FORM_TYPES = {
    simple_form: 1,
    ticket_fields_form: 2
  }
  FORM_TYPE_VALUES = FORM_TYPES.values
  POSITION_TYPES = {
    bottom_right: 1,
    bottom_left: 2
  }
  POSITION_TYPE_VALUES = POSITION_TYPES.values
end

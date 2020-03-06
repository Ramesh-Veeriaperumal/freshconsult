module HelpWidgetConstants
  HELP_WIDGET_FIELDS = %w[id product_id name settings freshmarketer solution_category_ids].freeze
  VALIDATION_CLASS = 'HelpWidgetValidation'.freeze
  DELEGATOR_CLASS = 'HelpWidgetDelegator'.freeze
  WHITELISTED_SETTINGS = %w[message button_text components contact_form appearance predictive_support widget_flow].freeze
  WHITELISTED_COMPONENTS = %w[contact_form solution_articles predictive_support].freeze
  WHITELISTED_CONTACT_FORM = %w[form_type form_title form_submit_message form_button_text screenshot attach_file captcha require_login].freeze
  WHITELISTED_APPEARANCE = %w[position offset_from_bottom offset_from_left offset_from_right color_schema gradient pattern theme_color theme_text_color button_color button_text_color].freeze
  WHITELISTED_PREDICTIVE_SUPPORT = %w[domain_list welcome_message message success_message].freeze
  FRESHMARKETER_FIELDS = %w[domain email type].freeze
  COMPONENTS = WHITELISTED_COMPONENTS
  CONTACT_FORM = WHITELISTED_CONTACT_FORM
  SETTINGS_FIELDS = WHITELISTED_SETTINGS
  APPEARANCE = WHITELISTED_APPEARANCE
  PREDICTIVE_SUPPORT = WHITELISTED_PREDICTIVE_SUPPORT
  CREATE_FIELDS = %w[product_id settings].freeze
  TEXT_FIELDS_MAX_LENGTH = 60
  BUTTON_TEXT_LENGTH = 40
  LAUNCHER_TEXT_LENGTH = 12
  TEXT_AREA_MAX_LENGTH = 150
  MAX_DOMAIN_ALLOWED = 3
  DOMAIN_VALADITION_REGEX = /^([a-zA-Z0-9][a-zA-Z0-9-]{1,63}(\.)){1,3}([a-zA-Z]{2,6})$/
  FRESHMARKETER_TYPE_MAPPING = {
    'create' => 'email',
    'associate' => 'domain'
  }.freeze
end

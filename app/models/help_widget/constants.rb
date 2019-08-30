class HelpWidget < ActiveRecord::Base
  FILE_PATH = 'widgets/%{widget_id}.json'.freeze
  ZERO_BYTE_FILE_PATH = 'widgets/%{widget_id}.js'.freeze
  BOOTSTRAP_REDIRECTION_PATH = '/widgetBase/bootstrap.js'.freeze
  THEME_COLOR = '#00a886'.freeze
  BUTTON_COLOR = '#12344d'.freeze
  OFFSET = 30

  COLOR_SCHEMA_TYPES = {
    gradient: 1,
    solid: 2
  }.freeze

  FORM_TYPES = {
    simple_form: 1,
    ticket_fields_form: 2
  }.freeze

  POSITION_TYPES = {
    bottom_right: 1,
    bottom_left: 2
  }.freeze

  PATTERN_TYPES = {
    pattern_one: 1,
    pattern_two: 2,
    pattern_three: 3,
    pattern_four: 4,
    pattern_five: 5,
    pattern_six: 6
  }.freeze

  GRADIENT_TYPES = {
    gradient_one: 1,
    gradient_two: 2,
    gradient_three: 3,
    gradient_four: 4,
    gradient_five: 5
  }.freeze

  WIDGET_FLOW_TYPES = {
    optimize_for_deflection: 1,
    neutral: 2
  }.freeze

  def self.default_settings(product = nil)
    portal = (product && product.portal) || Account.current.main_portal
    {
      message: product ? I18n.t('help_widget.name', name: product.name) : I18n.t('help_widget.message'),
      button_text: I18n.t('help_widget.button_text'),
      components: {
        contact_form: true,
        solution_articles: false
      },
      contact_form: {
        form_type: FORM_TYPES[:simple_form],
        form_title: I18n.t('help_widget.form_title'),
        form_button_text: I18n.t('help_widget.form_button_text'),
        form_submit_message: I18n.t('help_widget.form_submit_message'),
        attach_file: true,
        screenshot: false,
        captcha: true
      },
      appearance: {
        position: POSITION_TYPES[:bottom_right],
        offset_from_right: OFFSET,
        offset_from_left: OFFSET,
        offset_from_bottom: OFFSET,
        color_schema: COLOR_SCHEMA_TYPES[:gradient],
        gradient: GRADIENT_TYPES[:gradient_one],
        pattern: PATTERN_TYPES[:pattern_one],
        theme_color: THEME_COLOR,
        button_color: portal.try(:preferences).try(:[], :tab_color) || BUTTON_COLOR
      },
      predictive_support: {
        welcome_message: I18n.t('help_widget.welcome_message'),
        message: I18n.t('help_widget.predictive_message'),
        success_message: I18n.t('help_widget.success_message')
      },
      widget_flow: WIDGET_FLOW_TYPES[:neutral]
    }
  end
end

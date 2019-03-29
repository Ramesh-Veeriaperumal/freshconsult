class HelpWidget < ActiveRecord::Base
  FILE_PATH = 'widgets/%{widget_id}.json'.freeze
  ZERO_BYTE_FILE_PATH = 'widgets/%{widget_id}.js'.freeze
  BOOTSTRAP_REDIRECTION_PATH = '/widgetBase/bootstrap.js'.freeze

  DEFAULT_SETTINGS = {
    message: I18n.t('help_widget.message'),
    button_text: I18n.t('help_widget.button_text'),
    components: {
      contact_form: true,
      solution_articles: false
    },
    contact_form: {
      form_type: 1,
      form_title: I18n.t('help_widget.form_title'),
      form_button_text: I18n.t('help_widget.form_button_text'),
      form_submit_message: I18n.t('help_widget.form_submit_message'),
      attach_file: true,
      screenshot: false,
      captcha: true
    },
    appearance: {
      position: 1,
      offset_from_right: 30,
      offset_from_left: 30,
      offset_from_bottom: 30,
      color_schema: 1,
      gradient: 1,
      pattern: 1,
      theme_color: '#00a886',
      button_color: '#12344d'
    },
    predictive_support: {
      welcome_message: I18n.t('help_widget.welcome_message'),
      message: I18n.t('help_widget.predictive_message'),
      success_message: I18n.t('help_widget.success_message')
    },
    widget_flow: 2
  }.freeze
end

class HelpWidget < ActiveRecord::Base

  FILE_PATH = 'widgets/%{widget_id}.json'
  ZERO_BYTE_FILE_PATH = 'widgets/%{widget_id}.js'
  BOOTSTRAP_REDIRECTION_PATH = '/widgetBase/bootstrap.js'

  DEFAULT_SETTINGS = {
    :message => I18n.t('help_widget.message'),
    :button_text => I18n.t('help_widget.button_text'),
    :components => {
      :contact_form => true
    },
    :contact_form => {
      :form_type => 1,
      :form_title => I18n.t('help_widget.form_title'),
      :form_button_text => I18n.t('help_widget.form_button_text'),
      :form_submit_message => I18n.t('help_widget.form_submit_message'),
      :attach_file => true,
      :screenshot => true,
      :captcha => true,
    },
    :appearance => {
      :position => 1,
      :offset_from_right => 30,
      :offset_from_left => 30,
      :offset_from_bottom => 30,
      :height => 600,
      :theme_color => "#1054da",
      :button_color => "#16193e"
    }
  }
end

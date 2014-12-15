module AccountAdditionalSettings::AdditionalSettings

  include AccountConstants
  
  def email_template_settings
    (self.additional_settings.is_a?(Hash) and self.additional_settings[:email_template]) ? 
        self.additional_settings[:email_template] : DEFAULTS_FONT_SETTINGS[:email_template]
  end

  def font_settings=(settings = {})
    additional_settings = self.additional_settings
    email_template = (self.email_template_settings || {}).merge(settings)

    unless additional_settings.nil?
      additional_settings[:email_template] = email_template
      self.save
    else
      self.update_attributes(:additional_settings =>  { :email_template => email_template }) 
    end
  end

end
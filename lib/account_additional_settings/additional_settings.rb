module AccountAdditionalSettings::AdditionalSettings

  include AccountConstants

  DEFAULT_RLIMIT = {'helpdesk_tickets' => {'enable' => false},'helpdesk_notes' => {'enable' => false},
    'solution_articles' => {'enable' => false}}
  
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

  def set_payment_preference(paid_by_reseller)
    paid_by_reseller = PAID_BY_RESELLER[paid_by_reseller] || false
    additional_settings = self.additional_settings || {}
    additional_settings[:paid_by_reseller] = paid_by_reseller
    update_attributes(additional_settings: additional_settings)
  end
end
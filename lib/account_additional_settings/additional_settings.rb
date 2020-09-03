module AccountAdditionalSettings::AdditionalSettings

  include AccountConstants
  include Onboarding::OnboardingRedisMethods

  DEFAULT_RLIMIT = {'helpdesk_tickets' => {'enable' => false},'helpdesk_notes' => {'enable' => false},
    'solution_articles' => {'enable' => false}}
  ONBOARDING_VERSION_MAXIMUM_RETRY = 5
  
  def email_template_settings
    (self.additional_settings.is_a?(Hash) and self.additional_settings[:email_template]) ? 
        self.additional_settings[:email_template] : DEFAULTS_FONT_SETTINGS[:email_template]
  end

  def security
    (additional_settings || {})[:security] || {}
  end

  def font_settings=(settings = {})
    additional_settings = self.additional_settings
    email_template = (self.email_template_settings || {}).merge(settings)

    DEFAULTS_FONT_SETTINGS[:email_template].keys.each do |font_style|
      email_template[font_style] = DEFAULTS_FONT_SETTINGS[:email_template][font_style] if email_template[font_style].blank?
    end

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

  def mark_account_as_anonymous(precreated = false)
    additional_settings = self.additional_settings || {}
    additional_settings[:anonymous_account] = true
    additional_settings[:precreated_account] = precreated
    update(additional_settings: additional_settings)
    AccountCleanup::AnonymousAccountCleanup.perform_in(2.days, account_id: account_id) unless precreated
  end

  def set_onboarding_version
    metric = Account.current.conversion_metric
    member = metric.msegments if metric.present?
    self.additional_settings ||= {}
    if member.present? && metric.language == 'en' && ((metric.current_session_url == GrowthHackConfig[:freshdesk_signup] &&
       metrics_has_any_personalised_onboarding_keys?(metric.referrer)) ||
       metrics_has_any_personalised_onboarding_keys?(metric.current_session_url))
      self.additional_settings[:onboarding_ab_testing] = true
      self.additional_settings[:onboarding_version] = get_onboarding_version(member)
    else
      self.additional_settings[:onboarding_version] = GrowthHackConfig[:onboarding_types].first
    end
  end

  def metrics_has_any_personalised_onboarding_keys?(url)
    GrowthHackConfig[:personalised_onboarding_keywords].any? { |keywords| url.include?(keywords) } && url.exclude?(GrowthHackConfig[:competitor_keyword])
  end

  def get_onboarding_version(member)
    onboarding_types = GrowthHackConfig[:onboarding_types]
    ONBOARDING_VERSION_MAXIMUM_RETRY.times do
      watch_onboarding_version_redis
      result = hincrby_using_multi(ACCOUNT_ONBOARDING_VERSION, member, (account_onboarding_version(member).to_i.zero? ? 1 : -1))
      return onboarding_types[result.first] if result.is_a?(Array) && result[0].present?
    end
    onboarding_types.first
  end
end

class Account < ActiveRecord::Base

	validates_associated :account_configuration, :on => :create
	validates_format_of :domain, :with => /\A[a-zA-Z0-9]+-?[a-zA-Z0-9]+\Z/, :if => :full_domain_changed?
  validates_length_of :name, :in => 3..100, :too_long => I18n.t('long_company_name_error'), :too_short => I18n.t('short_company_name_error')
  validate :valid_domain?, :if => :full_domain_changed?
  validate :valid_sso_options?
  validate :valid_plan?, :valid_payment_info?, :valid_subscription?, on: :create
  validates_uniqueness_of :google_domain ,:allow_blank => true, :allow_nil => true
  validates_numericality_of :ticket_display_id,
                            :less_than => 100000000,
                            :message => "Value must be less than eight digits"
  validate :reserved_domain?

  def run_domain_validations
    Account.validators_on(:domain).each do |validator|
      validator.validate_each(self, :domain, self.domain)
      return false if self.errors[:domain].present?
    end
    return false if self.full_domain.split('.').count > 3
    return true
  end

  protected

  	def valid_domain?
      conditions = new_record? ? ['full_domain = ?', self.full_domain] : ['full_domain = ? and id <> ?', self.full_domain, self.id]
      self.errors[:base] << 'Domain is not available!' if self.full_domain.blank? || self.class.where(conditions).count > 0 || self.full_domain.split('.').count > 3
    end

    def reserved_domain?
      self.errors[:domain] << I18n.t('domain_not_available_msg', domain_name: "%{value}") if RESERVED_DOMAINS.include?(self.domain.downcase)
    end
    
    def valid_sso_options?
      if self.sso_enabled?
        self.sso_options[:sso_type] = SsoUtil::SSO_TYPES[:simple_sso] if self.sso_options[:sso_type].blank? && !self.freshid_sso_sync_enabled?
        if self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:simple_sso] && self.sso_options[:login_url].blank?
          self.errors.add(:sso_options, "#{I18n.t('admin.security.errors.simple_sso.invalid_login_url')}")
        elsif self.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:saml]
          self.errors.add(:sso_options, "#{I18n.t('admin.security.errors.saml_sso.invalid_login_url')}") if self.sso_options[:saml_login_url].blank?
          self.errors.add(:sso_options, "#{I18n.t('admin.security.errors.saml_sso.invalid_fingerprint')}") if self.sso_options[:saml_cert_fingerprint].blank?
        end
      end
    end

    def valid_payment_info?
      if needs_payment_info?
        unless @creditcard && @creditcard.valid?
          errors.add(:base,"Invalid payment information")
        end
        
        unless @address && @address.valid?
          errors.add(:base,"Invalid address")
        end
      end
    end
    
    def valid_plan?
      errors.add(:base,"Invalid plan selected.") unless @plan
    end
    
    def valid_subscription?
      return if errors.any? # Don't bother with a subscription if there are errors already
      if !subscription.valid?
        errors.add(:base,"Error with payment: #{subscription.errors.full_messages.to_sentence}")
        return false
      end
    end

end

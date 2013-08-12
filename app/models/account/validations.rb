class Account < ActiveRecord::Base

	validates_associated :account_configuration, :on => :create
	validates_format_of :domain, :with => /(?=.*?[A-Za-z])[a-zA-Z0-9]*\Z/
  validates_exclusion_of :domain, :in => RESERVED_DOMAINS, :message => I18n.t('domain_not_available_msg', :domain_name => "%{value}")
  validates_length_of :name, :in => 3..100, :too_long => I18n.t('long_company_name_error'), :too_short => I18n.t('short_company_name_error')
  validate :valid_domain?, :valid_sso_options?
  validate_on_create :valid_plan?, :valid_payment_info?, :valid_subscription?
  validates_uniqueness_of :google_domain ,:allow_blank => true, :allow_nil => true
  validates_numericality_of :ticket_display_id,
                            :less_than => 1000000,
                            :message => "Value must be less than six digits"

  protected

  	def valid_domain?
      conditions = new_record? ? ['full_domain = ?', self.full_domain] : ['full_domain = ? and id <> ?', self.full_domain, self.id]
      self.errors.add_to_base('domain is not available') if self.full_domain.blank? || self.class.count(:conditions => conditions) > 0
    end
    
    def valid_sso_options?
      if self.sso_enabled?
        if self.sso_options[:login_url].blank?  
          self.errors.add(:sso_options, ', Please provide a valid login url') 
        #else
          #self.errors.add(:sso_options, ', Please provide a valid login url') if !external_url_is_valid?(self.sso_options[:login_url])
        end
      end
    end

    def valid_payment_info?
      if needs_payment_info?
        unless @creditcard && @creditcard.valid?
          errors.add_to_base("Invalid payment information")
        end
        
        unless @address && @address.valid?
          errors.add_to_base("Invalid address")
        end
      end
    end
    
    def valid_plan?
      errors.add_to_base("Invalid plan selected.") unless @plan
    end
    
    def valid_subscription?
      return if errors.any? # Don't bother with a subscription if there are errors already
      self.build_subscription(:plan => @plan, :next_renewal_at => @plan_start, :creditcard => @creditcard, :address => @address, :affiliate => @affiliate)
      if !subscription.valid?
        errors.add_to_base("Error with payment: #{subscription.errors.full_messages.to_sentence}")
        return false
      end
    end

end
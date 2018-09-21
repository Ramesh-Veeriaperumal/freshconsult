class AccountConfiguration < ActiveRecord::Base
  include Redis::RedisKeys
  include Redis::OthersRedis

  self.primary_key = :id
  belongs_to_account

  serialize :contact_info, Hash
  serialize :billing_emails, Hash
  serialize :company_info, Hash

  validate :ensure_values
  validate :admin_notification_emails, on: :update, if: :notification_email_changed?

  after_update :update_billing, :update_reseller_subscription
  after_commit :update_crm_and_map, on: :update, :unless => :sandbox?
  after_commit :populate_industry_based_default_data, on: :update
  include Concerns::DataEnrichmentConcern

  CONTACT_INFO_KEYS = [:full_name, :first_name, :last_name, :email, :notification_emails,  :job_title, :phone]
  COMPANY_INFO_KEYS = [:name, :industry]
  COMPANY_INFO_KEYS_WITH_PREFIX = COMPANY_INFO_KEYS.map { |each| "company_#{each}"}
  COMPANY_INDUSTRY_TYPES  = YAML.load_file(File.join(Rails.root, 'config', 'company_industries.yml')).keys

  CONTACT_INFO_KEYS.each do |method_name|
    define_method "admin_#{method_name.to_s}" do
      contact_info[method_name]
    end

    define_method("admin_#{method_name}=") do |value|
      contact_info_will_change! unless contact_info_changed?
      contact_info[method_name] = value
    end

    alias_method "#{method_name}=", "admin_#{method_name}="
  end

  COMPANY_INFO_KEYS.each do |method_name|
    define_method "admin_company_#{method_name.to_s}" do
      company_info[method_name]
    end

    define_method("admin_company_#{method_name}=") do |value|
      company_info_will_change! unless company_info_changed?
      company_info[method_name] = value
    end

    alias_method "company_#{method_name}=", "admin_company_#{method_name}="
  end


  def notification_emails
    all_admin_emails = account.account_managers.collect {|admin| admin.email.downcase}
    admin_notification_emails = all_admin_emails & contact_info[:notification_emails].to_a.map(&:downcase)
    admin_notification_emails = all_admin_emails & [admin_email.downcase] if admin_notification_emails.blank?
    admin_notification_emails.presence || all_admin_emails
  end

  def invoice_emails
  	billing_emails[:invoice_emails]
  end

  def email_updated?
    contact_info_changes = previous_changes['contact_info']
    contact_info_changes && (contact_info_changes[0][:email] != contact_info_changes[1][:email])
  end

  def company_contact_info_updated?
    [:contact_info, :company_info].any? {|k| previous_changes.key?(k)}
  end

  def update_contact_company_info!(user_params)
    self.update_attributes!(user_params.slice(*(CONTACT_INFO_KEYS + COMPANY_INFO_KEYS_WITH_PREFIX)))
  end

  private

    def ensure_values
      if (contact_info[:first_name].blank? or contact_info[:email].blank? or billing_emails[:invoice_emails].blank?)
        errors.add(:base,I18n.t("activerecord.errors.messages.blank"))
      end
    end

    def notification_email_changed?
      contact_info_changed? && changes['contact_info'][0][:notification_emails].to_a.sort != changes['contact_info'][1][:notification_emails].to_a.sort
    end

    def admin_notification_emails
      admin_emails = account.account_managers.map(&:email) & contact_info[:notification_emails].to_a
      if admin_emails.empty?
        account.errors.add(:base, I18n.t('validation.email'))
      end
    end

  	def update_crm_and_map
      if (Rails.env.production? or Rails.env.staging?) && company_contact_info_updated?
        CRMApp::Freshsales::AdminUpdate.perform_at(15.minutes.from_now, {
          account_id: account_id, 
          item_id: id
        })
        Subscriptions::AddLead.perform_at(15.minutes.from_now, {:account_id => account_id, :old_email => previous_email})
      end
    end

    def previous_email
      email_updated? ? previous_changes['contact_info'][0]["email"] : nil
    end

  	def update_billing
  		Billing::Subscription.new.update_admin(self)
  	end

    def update_reseller_subscription
      Subscription::UpdatePartnersSubscription.perform_async({ :account_id => account_id,
        :event_type => :contact_updated })
    end

    def sandbox?
      self.account.sandbox?
    end

    def populate_industry_based_default_data
      # User.current check added to segregate updates triggered by contact enrichment sidekiq worker
      if User.current.nil? && company_contact_info_updated? && !Account.current.sample_data_setup? && Account.current.subscription.trial?
        DefaultDataPopulation.perform_async({:industry => company_info[:industry]})
      end
    end
end

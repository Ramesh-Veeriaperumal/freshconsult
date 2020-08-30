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
  after_update :update_billing, :update_reseller_subscription, unless: :anonymous_account?
  after_commit :update_crm_and_map, on: :update, unless: [:sandbox?, :anonymous_account?]
  after_commit :publish_account_central_payload, on: :update, unless: [:sandbox?, :is_anonymous_account?]
  after_commit :populate_industry_based_default_data, on: :update
  after_commit :update_helpdesk_name, on: :update
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

  def account_configuration_for_central
    {
      first_name: contact_info[:first_name],
      last_name: contact_info[:last_name],
      anonymous_account: company_info[:anonymous_account],
      work_number: contact_info[:phone],
      email: contact_info[:email],
      job_title: contact_info[:job_title],
      twitter: contact_info[:twitter],
      facebook: contact_info[:facebook],
      linkedin: contact_info[:linkedin],
      time_zone: contact_info[:time_zone],
      address: company_info.try(:[], :location).try(:[], :streetName),
      city: company_info.try(:[], :location).try(:[], :city),
      state: company_info.try(:[], :location).try(:[], :state),
      zipcode: company_info.try(:[], :location).try(:[], :postalCode),
      country: company_info.try(:[], :location).try(:[], :country),
      industry_type_id: company_info[:industry],
      phone: company_info.fetch(:phone_numbers, []).join(','),
      number_of_employees: company_info.try(:[], :metrics).try(:[], :employees),
      annual_revenue: company_info.try(:[], :metrics).try(:[], :annualRevenue)
    }
  end

  private

    def ensure_values
      if (contact_info[:first_name].blank? or contact_info[:email].blank? or billing_emails[:invoice_emails].blank?)
        errors.add(:base,I18n.t("activerecord.errors.messages.blank"))
      end
      if contact_info[:first_name].to_s.include?(".") or contact_info[:last_name].to_s.include?(".")
        errors.add(:base, I18n.t("activerecord.errors.messages.invalid"))
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
        }) unless account.disable_freshsales_api_integration?
        Subscriptions::AddLead.perform_at(15.minutes.from_now, {:account_id => account_id, :old_email => previous_email})
      end      
    end

    def publish_account_central_payload
      if company_contact_info_updated?
        if account.model_changes.nil? 
          account.model_changes = account_configuration_changes(previous_changes)
        else
          account.model_changes.merge!(account_configuration_changes(previous_changes))
        end         
        account.manual_publish_to_central(nil, :update, nil, false)
        account.model_changes.delete(:account_configuration)
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

    def is_anonymous_account?
      anonymous_account = company_info.key?(:anonymous_account) ? company_info[:anonymous_account] : true     
      account.anonymous_account? && anonymous_account
    end

    def anonymous_account?
      account.anonymous_account?
    end

    def account_configuration_changes(model_changes)
      changes = [account_configuration_for_central, account_configuration_for_central]
      contact_info = model_changes['contact_info']
      if contact_info.present? && contact_info.length == 2
        changes[0][:first_name] = contact_info[0][:first_name]
        changes[0][:last_name] = contact_info[0][:last_name]
        changes[0][:work_number] = contact_info[0][:phone]
        changes[0][:email] = contact_info[0][:email]
        changes[0][:job_title] = contact_info[0][:job_title]
        changes[0][:twitter] = contact_info[0][:twitter]
        changes[0][:facebook] = contact_info[0][:facebook]
        changes[0][:time_zone] = contact_info[0][:time_zone]
      end
      company_info = model_changes['company_info']
      if company_info.present? && company_info.length == 2
        changes[0][:industry_type_id] = company_info[0][:industry]
        changes[0][:anonymous_account] = company_info[0][:anonymous_account]
        changes[0][:phone] = company_info[0].fetch(:phone_numbers, []).join(',')
        prev_location = company_info[0].fetch(:location, {})
        changes[0][:address] = prev_location[:streetName]
        changes[0][:city] = prev_location[:city]
        changes[0][:state] = prev_location[:state]
        changes[0][:zipcode] = prev_location[:postalCode]
        changes[0][:country] = prev_location[:country]
        prev_metrics = company_info[0].fetch(:metrics, {})
        changes[0][:number_of_employees] = prev_metrics[:employees]
        changes[0][:annual_revenue] = prev_metrics[:annualRevenue]
      end
      { account_configuration: changes }
    end

    def update_helpdesk_name
      unless previous_changes['company_info'].nil?
        to_company_name = previous_changes['company_info'][1][:name]
        if previous_changes['company_info'][0][:name] != to_company_name
          account.helpdesk_name = to_company_name
          account.save!
        end
      end
    end
end

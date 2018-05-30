class AccountConfiguration < ActiveRecord::Base
  include Redis::RedisKeys
  include Redis::OthersRedis

  self.primary_key = :id
  belongs_to_account

  serialize :contact_info, Hash
  serialize :billing_emails, Hash
  serialize :company_info, Hash

  validate :ensure_values

  after_update :update_billing, :update_reseller_subscription
  after_commit :update_crm_and_map, on: :update, :unless => :sandbox?
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
    contact_info[:notification_emails] || [admin_email]
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

  	def update_crm_and_map
      if (Rails.env.production? or Rails.env.staging?) && company_contact_info_updated?
        if redis_key_exists?(FRESHSALES_ADMIN_UPDATE)
          CRMApp::Freshsales::AdminUpdate.perform_at(15.minutes.from_now, {
            account_id: account_id, 
            item_id: id
          })
        else
          Resque.enqueue_at(15.minutes.from_now, CRM::AddToCRM::UpdateAdmin, {:account_id => account_id, :item_id => id})
        end
        if redis_key_exists?(SIDEKIQ_MARKETO_QUEUE)
          Subscriptions::AddLead.perform_at(15.minutes.from_now, {:account_id => account_id, :old_email => previous_email})
        else
          Resque.enqueue_at(15.minutes.from_now, Marketo::AddLead, {:account_id => account_id, :old_email => previous_email})
        end
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

end

class AccountConfiguration < ActiveRecord::Base

  self.primary_key = :id
  belongs_to_account

  serialize :contact_info, Hash
  serialize :billing_emails, Hash

  validate :ensure_values

  after_update :update_crm, :update_billing, :update_reseller_subscription


  def admin_first_name
  	contact_info[:first_name]
  end

	def admin_last_name
  	contact_info[:last_name]
  end

  def admin_email
    contact_info[:email]
  end

  def notification_emails
    contact_info[:notification_emails] || [admin_email]
  end

  def admin_phone
  	contact_info[:phone]
  end

  def invoice_emails
  	billing_emails[:invoice_emails]
  end

  private

  	def ensure_values
      if (contact_info[:first_name].blank? or contact_info[:email].blank? or billing_emails[:invoice_emails].blank?)
        errors.add(:base,I18n.t("activerecord.errors.messages.blank"))
      end
  	end

  	def update_crm
  		Resque.enqueue_at(15.minutes.from_now, CRM::AddToCRM::UpdateAdmin, {:account_id => account_id, :item_id => id})
  	end

  	def update_billing
  		Billing::Subscription.new.update_admin(self)
  	end

    def update_reseller_subscription
      Resque.enqueue(Subscription::UpdateResellerSubscription, { :account_id => account_id, 
        :event_type => :contact_updated })
    end

end

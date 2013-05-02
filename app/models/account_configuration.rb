class AccountConfiguration < ActiveRecord::Base

  belongs_to_account

  serialize :contact_info, Hash
  serialize :billing_emails, Hash

  validate :ensure_values

  after_update :update_crm, :update_billing

  
  def admin_first_name
  	contact_info[:first_name]
  end

	def admin_last_name
  	contact_info[:last_name]
  end

  def admin_email
  	contact_info[:email]
  end

  def admin_phone
  	contact_info[:phone]
  end	

  def invoice_emails
  	billing_emails[:invoice_emails]
  end

  private

  	def ensure_values
  		if (contact_info[:first_name].blank? or contact_info[:last_name].blank? or 
  						contact_info[:email].blank? or billing_emails[:invoice_emails].blank?)
  			errors.add_to_base(I18n.t("errors.blank"))
  		end
  	end

  	def update_crm
  		Resque.enqueue(CRM::AddToCRM::UpdateAdmin, {:account_id => account_id, :item_id => id})
  	end

  	def update_billing
  		Billing::Subscription.new.update_admin(self)
  	end

end
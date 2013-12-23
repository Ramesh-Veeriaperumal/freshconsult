class Freshfone::Credit < ActiveRecord::Base
	belongs_to_account
	set_table_name :freshfone_credits
	alias_attribute :credit, :last_purchased_credit
	
	attr_accessor :selected_credit
	#validates_inclusion_of :selected_credit, :in => [25, 50, 100] 
	attr_protected :account_id

	CREDIT_LIMIT = {
		:minimum => 0,
		:calling_threshold => 0.50,
		:safe_threshold => 1,
		:threshold => 5
	}
	def purchase
		begin
			response = Billing::Subscription.new.purchase_freshfone_credits(account, selected_credit)
    rescue Exception => e
      failed_purchase(selected_credit, e)
    end

    if response
      update_attributes({
      	:available_credit => total_credit, 
      	:last_purchased_credit => selected_credit
      })
      account.freshfone_payments.create(
        :status => true,
        :purchased_credit => selected_credit
      )
    end
    response
	end

	def enable_auto_recharge(recharge_qty)
		update_attributes(:auto_recharge => true, :recharge_quantity => recharge_qty)
	end

	def disable_auto_recharge
		update_attributes(:auto_recharge => false, :recharge_quantity => nil)
	end

	def freshfone_suspended?
		account.freshfone_account.suspended? if account.freshfone_account.present?
	end

	def update_credit(rate)
		update_attributes!(:available_credit => 
											self.available_credit - rate)
	end

	def other_charges(rate, billing_type, freshfone_number_id)
		account.freshfone_other_charges.create(:action_type => billing_type, :debit_payment => rate, 
			:freshfone_number_id => freshfone_number_id)
	end

	def renew_number(rate, freshfone_number_id)
		if update_credit(rate)
			other_charges(rate, Freshfone::OtherCharge::ACTION_TYPE_HASH[:number_renew], 
				freshfone_number_id)
			self.available_credit >= CREDIT_LIMIT[:minimum]
		else
			false
		end
	end

	def perform_auto_recharge
		self.selected_credit = recharge_quantity
		purchase
	end

	def zero_balance?
		available_credit <= CREDIT_LIMIT[:minimum]
	end
	
	def below_calling_threshold?
		available_credit <= CREDIT_LIMIT[:calling_threshold]
	end

	def below_safe_threshold?
		available_credit <= CREDIT_LIMIT[:safe_threshold]
	end

	private

		def total_credit
			available_credit + selected_credit
		end

		def failed_purchase(selected_credit, error)
	    account.freshfone_payments.create(
	        :status => false,
	        :purchased_credit => selected_credit,
	        :status_message => error.error_code
	      )
	  end
end
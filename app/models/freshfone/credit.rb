class Freshfone::Credit < ActiveRecord::Base
	belongs_to_account
	set_table_name :freshfone_credits
	alias_attribute :credit, :last_purchased_credit
	
	attr_accessor :selected_credit
	#validates_inclusion_of :selected_credit, :in => [25, 50, 100] 
	attr_protected :account_id

	CREDIT_LIMIT = {
		:minimum => 0,
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

	def renew_number(rate)
		if update_credit(rate)
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
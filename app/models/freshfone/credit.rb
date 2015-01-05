class Freshfone::Credit < ActiveRecord::Base
  self.primary_key = :id
	include ActionView::Helpers::NumberHelper
	
	belongs_to_account
	self.table_name =  :freshfone_credits
	alias_attribute :credit, :last_purchased_credit

	CREDIT_LIMIT = {
		:minimum => 0,
		:calling_threshold => 0.50,
		:safe_threshold => 1,
		:auto_recharge_threshold => 5,
		:recharge_alert => 7
	}

	RECHARGE_THRESHOLD = 25
	RECHARGE_OPTIONS = [25, 50, 100, 250, 500, 1000, 2500, 5000]
	DEFAULT = 100

	attr_accessor :selected_credit
	validates_numericality_of :recharge_quantity, :if => :auto_recharge? , :greater_than_or_equal_to => RECHARGE_THRESHOLD
	attr_protected :account_id

	def purchase
		begin
			response = Billing::Subscription.new.purchase_freshfone_credits(account, selected_credit)
    rescue Exception => e
    	Rails.logger.error "Error purchasing freshfone credits. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      failed_purchase(selected_credit, e)
    end

    if response
			update_credit(selected_credit)
      account.freshfone_payments.create(
        :status => true,
        :purchased_credit => selected_credit
      )
      FreshfoneNotifier.recharge_success(account, selected_credit, available_credit)
    else
     	FreshfoneNotifier.recharge_failure(account, selected_credit, available_credit)
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

	def deduce(rate)
		update_credit(-rate)
	end

	def renew_number(rate, freshfone_number_id)
		if deduce(rate)
			account.freshfone_other_charges.create(
				:action_type => Freshfone::OtherCharge::ACTION_TYPE_HASH[:number_renew],
				:debit_payment => rate,
				:freshfone_number_id => freshfone_number_id)
		else
			false
		end
	end

	def perform_auto_recharge
		self.selected_credit = recharge_quantity
		purchase if valid_auto_recharge?
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

	def auto_recharge_threshold_reached?
		available_credit <= CREDIT_LIMIT[:auto_recharge_threshold]
	end

	def recharge_alert?
		available_credit <= CREDIT_LIMIT[:recharge_alert]
	end

	def valid_recharge_amount?
		selected_credit >= RECHARGE_THRESHOLD
	end

	private

		def failed_purchase(selected_credit, error)
	    account.freshfone_payments.create(
	        :status => false,
	        :purchased_credit => selected_credit,
	        :status_message => error.error_code
	      )
	  end

	  def valid_auto_recharge?
	  	credit = Freshfone::Credit.find_by_account_id(account_id)
	  	credit.available_credit <= CREDIT_LIMIT[:auto_recharge_threshold]
	  end

	  def update_credit(credits)
      return false unless credits.is_a? Numeric
    	connection.execute(update_sql_query(credits))
    	self.reload
    	credit_observer = Freshfone::CreditObserver.instance
    	credit_observer.after_credit_update(self)
      return true
	  end

	  def update_sql_query(credits)
	  	updated_at = Time.now.to_s(:db)
    	sql_query = "UPDATE freshfone_credits set available_credit = available_credit + #{credits},"
    	sql_query << " last_purchased_credit = #{credits}," if (credits > 0 )
    	sql_query << "updated_at = '#{updated_at}' WHERE account_id= #{account.id}"
	  end
end
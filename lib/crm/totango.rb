class CRM::Totango

	QUEUE = "totango_queue"

	class TotangoUrl
		extend CRM::SendEventToTotango
	end

	class SendUserAction < TotangoUrl
		@queue = QUEUE
		def self.perform(account_id, user, activity)
			account = Account.find(account_id)
			send_event("#{account_id}&sdr_odn=#{account.full_domain}"+
						"&sdr_u=#{user}&sdr_a=#{activity["action"]}&sdr_m=#{activity["module"]}")
		end
	end

	class TrialCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(account_id)
			account = Account.find(account_id)
    		send_event("#{account_id}&sdr_odn=#{account.full_domain}"+
    			"&sdr_o.Status=Trial&sdr_o.Creation+Date=#{account.created_at}")
  		end
	end

	class FreeCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(subscription_id)
			subscription = Subscription.find(subscription_id)
			send_event("#{subscription.account.id}&sdr_o.Status=Free"+
				"&sdr_o.Licenses=3&sdr_o.Revenue=0&sdr_o.Plan=Sprout")
		end
	end

	class PaidCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(payment_id)
			payment = SubscriptionPayment.find(payment_id)
			send_event("#{payment.account.id}&sdr_o.Status=Paying"+
				"&sdr_o.Licenses=#{payment.subscription.agent_limit}"+
				"&sdr_o.Revenue=#{payment.subscription.amount}&sdr_o.Plan=#{payment.plan_name}")
		end
	end

	class CanceledCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(account_id)
			send_event("#{account_id}&sdr_o.Status=Canceled")
		end
	end
end
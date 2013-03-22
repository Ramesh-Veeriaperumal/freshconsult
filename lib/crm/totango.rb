class CRM::Totango

	QUEUE = "totango_queue"

	class TotangoUrl
		extend CRM::SendEventToTotango
		extend Resque::AroundPerform
	end

	class SendUserAction < TotangoUrl
		@queue = QUEUE
		def self.perform(args)
			account = Account.current
			user = args[:email]
			activity = args[:activity]
			send_event("#{account.id}&sdr_odn=#{account.full_domain}"+
						"&sdr_u=#{user}&sdr_a=#{activity["action"]}&sdr_m=#{activity["module"]}")
		end
	end

	class TrialCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(args)
			account = Account.current
    		send_event("#{account.id}&sdr_odn=#{account.full_domain}"+
    			"&sdr_o.Status=Trial&sdr_o.Creation+Date=#{account.created_at}")
  		end
	end

	class FreeCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(args)
			account = Account.current
			send_event("#{account.id}&sdr_o.Status=Free"+
				"&sdr_odn=#{account.full_domain}"+
				"&sdr_o.Licenses=3&sdr_o.Revenue=0&sdr_o.Plan=Sprout")
		end
	end

	class PaidCustomer < TotangoUrl
		@queue = QUEUE
		def self.perform(args)
			account = Account.current
			payment = SubscriptionPayment.find_by_account_id_and_id(account.id,args[:payment_id])
			send_event("#{account.id}&sdr_o.Status=Paying"+
				"&sdr_odn=#{account.full_domain}"+
				"&sdr_o.Licenses=#{payment.subscription.agent_limit}"+
				"&sdr_o.Revenue=#{payment.amount}&sdr_o.Plan=#{payment.plan_name}")
		end
	end

	class CanceledCustomer
		extend CRM::SendEventToTotango
		@queue = QUEUE
		
		def self.perform(account_id, full_domain)
			send_event("#{account_id}&sdr_o.Status=Canceled&sdr_odn=#{full_domain}")
		end
	end
end
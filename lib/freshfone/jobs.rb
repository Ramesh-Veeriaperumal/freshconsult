module Freshfone::Jobs
  QUEUE = "FRESHFONE_QUEUE"
  
	class FoneJobs 
		extend Resque::AroundPerform

		def self.perform(args)
			perform_job(args) 
		end
	end

	class CallBilling < FoneJobs
		@queue = QUEUE


		def self.perform_job(args)
			calculator = Freshfone::CallCostCalculator.new(args, Account.current)
			calculator.perform
		end
		# VVERBOSE=1 QUEUE=FRESHFONE_QUEUE rake resque:work
	end
	
	class AttachmentsDelete < FoneJobs
		@queue = QUEUE

		def self.perform_job(args)
			account = Account.current
			attachments = account.attachments.find_all_by_id(args[:attachment_ids])
			attachments.each { |attachment| attachment.destroy }
		end
	end

end

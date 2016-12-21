module SpamDetection
	class LearnTicketWorker < BaseWorker

		sidekiq_options :queue => :learn_spam_message, :retry => 3, :backtrace => true, :failures => :exhausted

		def perform(args)
			account = Account.current
			Rails.logger.info "Learning ticket by SDS for Account-Id: #{account.id} and Ticket-Id: #{args['ticket_id']}"
			return if (args['ticket_id'].blank? || args['type'].blank?)
			method = (args['type'].to_i == 1) ? "learn_spam" : "learn_ham"
			ticket = account.tickets.find(args['ticket_id'])
			email = Helpdesk::Email::SpamDetector.fetch_mail(ticket)
			if email.blank?
				Rails.logger.info "Email content is not available"
				return
			end
			sds = FdSpamDetectionService::Service.new(account.id, email)
			res = sds.send(method)
			Rails.logger.info "Response from sds for learning email: #{res}"
			raise "Unable to connect to spam detection service" if res.eql?(false)
		end
	end
end
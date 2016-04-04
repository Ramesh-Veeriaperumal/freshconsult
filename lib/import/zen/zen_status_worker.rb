class Import::Zen::ZenStatusWorker < Struct.new(:params)
	include Import::Zen::Redis

	attr_accessor :status

	def initialize(params={})
		self.status = get_full_hash(zi_key)
	end

	def perform
		if completed?
			Admin::DataImportMailer.import_summary({ :user => current_agent.user })
			Account.current.zendesk_import.destroy
		else
			Resque.enqueue_at(1.hour.from_now, Import::Zen::ZendeskImportStatus, 
                                    { :account_id => Account.current.id })
		end
	end

	protected
	
		def completed?
			nodes = JSON.parse(status['nodes'])
			nodes.each do |node|
				if status[node].present? && status[node].to_i != Admin::DataImport::ZEN_IMPORT_STATUS[:completed]
					return false
				elsif status[node].present? && node.eql?('ticket')
					return false unless (ticket_completed?) && (attachment_completed?)
				end
			end
			return true
		end

		def ticket_completed?
			(status["total_tickets"].to_i != 0) && (status["total_tickets"].to_i == status["tickets_completed"].to_i)
		end

		def attachment_completed?
			(status["attachments_completed"].to_i == status["attachments_queued"].to_i)
		end

		def current_agent
			Account.current.agents.find(status['current_user'])
		end
end
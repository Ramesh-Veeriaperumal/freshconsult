class Community::DeactivateMonitorship < BaseWorker

	sidekiq_options :queue => :deactivate_monitorship, :retry => 0, :failures => :exhausted

	def perform(user_id)
		user = Account.current.all_users.find_by_id(user_id)
		if user.present?
			user.monitorships.active_monitors.find_in_batches(:batch_size => 100) do |objects|
				Monitorship.where(:id => objects.map(&:id)).update_all(:active => false)
			end
		else
			Rails.logger.info "DeactivateMonitorship: account #{Account.current.id} - User not found #{user_id}"
		end
	rescue => e
		Rails.logger.error("DeactivateMonitorship: account #{Account.current.id} - User #{user_id} \n#{e.message} \n#{e.backtrace.to_a.join("\n")}")
		NewRelic::Agent.notice_error(e,{:description => "DeactivateMonitorship: account #{Account.current.id} - User #{user_id}"})
	end
end

class Community::DeactivateMonitorship < BaseWorker

	sidekiq_options :queue => :deactivate_monitorship, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(user_id)
		user = Account.current.all_users.find(user_id)
		user.monitorships.active_monitors.find_in_batches(:batch_size => 100) do |objects|
			Monitorship.where(:id => objects.map(&:id)).update_all(:active => false)
		end
	end
end

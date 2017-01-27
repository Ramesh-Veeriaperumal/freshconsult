class ManualPublishWorker < RabbitmqWorker
	 sidekiq_options :queue => 'manual_publish', :retry => 5, :dead => true, :failures => :exhausted

end
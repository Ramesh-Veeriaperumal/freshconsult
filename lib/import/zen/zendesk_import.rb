class Import::Zen::ZendeskImport
	extend Resque::AroundPerform

	@queue = "zendeskImport"

	def self.perform(zen_params)
		$spam_watcher.setex("#{zen_params[:account_id]}-",24.hours,"true")
		Import::Zen::Start.new(zen_params).perform
		$spam_watcher.del("#{zen_params[:account_id]}-")
	end
end

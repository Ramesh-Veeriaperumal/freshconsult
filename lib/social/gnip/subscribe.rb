class Social::Gnip::Subscribe
	extend Resque::AroundPerform
	include Social::Gnip::Constants

	@queue = "gnip_subscribe_worker"

	def self.perform(args)
		account = Account.current
		twitter_handle = account.twitter_handles.find(args[:twitter_handle_id])
		rule = Social::Gnip::Rule.new(twitter_handle, {:subscribe => true})
		gnip_streams = rule.streams
		gnip_streams.each do |stream|
			rule.set_stream(stream)
			rule.add
		end
	end
end

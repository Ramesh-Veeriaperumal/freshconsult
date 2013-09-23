class Social::Gnip::Unsubscribe
	extend Resque::AroundPerform
	include Social::Gnip::Constants

	@queue = "gnip_unsubscribe_worker"

	def self.perform(args)
		account = Account.current
		rule = Social::Gnip::Rule.new(nil, {:account => account})
		gnip_streams = rule.streams
		gnip_streams.each do |stream|
			rule.set_stream(stream)
			rule.remove(args)
		end
	end
end

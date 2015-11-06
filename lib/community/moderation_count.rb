module Community::ModerationCount

	def fetch_spam_counts
		@counts = {}
		Post::SPAM_SCOPES_DYNAMO.each do |key, filter|
			count = SpamCounter.send("#{key}_count")
			@counts[key] = count < 0 ? 0 : count
		end
		@counts
	end

end
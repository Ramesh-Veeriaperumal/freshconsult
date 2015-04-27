module Community::ModerationCount

	def fetch_spam_counts
		@counts = {}
		Post::SPAM_SCOPES_DYNAMO.each do |key, filter|
			@counts[key] = SpamCounter.send("#{key}_count")
		end
	end

end
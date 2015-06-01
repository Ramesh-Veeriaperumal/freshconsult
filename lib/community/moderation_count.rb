module Community::ModerationCount

	def fetch_spam_counts
		current_account.features?(:spam_dynamo) ? fetch_counts_dynamo : fetch_counts_mysql
	end

	def fetch_counts_mysql
		@counts = {}
		Post::SPAM_SCOPES.each do |key, filter|
			@counts[key] = current_account.posts.send(filter).count
		end
	end

	def fetch_counts_dynamo
		@counts = {}
		Post::SPAM_SCOPES_DYNAMO.each do |key, filter|
			@counts[key] = SpamCounter.send("#{key}_count",current_account.id)
		end
	end

end
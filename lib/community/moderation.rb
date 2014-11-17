module Community::Moderation
	def moderation_enabled?
		CommunityConstants::MODERATE.keys.each do |f|
		  return true if current_account.features_included?(f)
		end
		false
	end

	def flash_msg_on_post_create
		key = moderation_enabled? ? 'success' : "moderation_none.post"
		t(".flash.portal.discussions.topics.#{key}")
	end

	def flash_msg_on_topic_create
		key = moderation_enabled? ? 'spam_check' : "moderation_none.topic"
		t(".flash.portal.discussions.topics.#{key}")
	end

end

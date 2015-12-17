class Workers::Community::DispatchSpamDigest
	extend Resque::AroundPerform

	@queue = "spam_digest_mailer"

	class << self

		def perform(args)

			moderation_digest = HashWithIndifferentAccess.new({
									:unpublished_count => SpamCounter.elaborate_count("unpublished"), 
									:spam_count => SpamCounter.elaborate_count("spam")
								})

			moderation_digest.delete(:unpublished_count) unless can_send_approval_digest?(moderation_digest)

			unless counters_blank(moderation_digest)
				Time.zone = Account.current.time_zone
				Account.current.forum_moderators.each do |moderator|
					SpamDigestMailer.spam_digest({
							:account => Account.current,
							:recipients => moderator.email,
							:moderator => moderator.user,
							:subject => %(Topics waiting for approval in #{Account.current.name} - #{Time.zone.now.strftime(Timezone::Constants::MAIL_FORMAT)}),
							:moderation_digest => moderation_digest,
							:host => Account.current.full_url 
						}) unless moderator.email.blank?
				end
			end
		end

		def can_send_approval_digest?(moderation_digest)
			reject_blank_values(moderation_digest[:unpublished_count]).present? || 
						(Account.current.features_included?(:moderate_all_posts) || Account.current.features_included?(:moderate_posts_with_links))
		end

		def reject_blank_values(counter)
			counter.reject { |k,v| v <= 0 }
		end

		def counters_blank(moderation_digest)
			moderation_digest.reject { |k,v| reject_blank_values(v).blank? }.blank?
		end
	end
end
class Workers::Community::DispatchSpamDigest
	extend Resque::AroundPerform

	@queue = "spam_digest_mailer"

	class << self

		def perform(args)
			args.symbolize_keys!

			Sharding.select_shard_of(args[:account_id]) do 

				account = Account.find(args[:account_id])

				moderation_digest = HashWithIndifferentAccess.new({
										:unpublished_count => SpamCounter.elaborate_count(account.id, "unpublished"), 
										:spam_count => SpamCounter.elaborate_count(account.id, "spam")
									})

				moderation_digest.delete(:unpublished_count) unless can_send_approval_digest?(account, moderation_digest)

				unless counters_blank(moderation_digest)
					Time.zone = account.time_zone
					account.forum_moderators.each do |moderator|
						SpamDigestMailer.deliver_spam_digest({
								:account => account,
								:recipients => moderator.email,
								:moderator => moderator.user,
								:subject => %(Topics waiting for approval in #{account.helpdesk_name} - #{Time.zone.now.strftime(Timezone::Constants::MAIL_FORMAT)}),
								:moderation_digest => moderation_digest,
								:host => account.full_url 
							}) unless moderator.email.blank?
					end
				end
			end
		end

		def can_send_approval_digest?(account, moderation_digest)
			reject_blank_values(moderation_digest[:unpublished_count]).present? || 
						(account.features_included?(:moderate_all_posts) || account.features_included?(:moderate_posts_with_links))
		end

		def reject_blank_values(counter)
			counter.reject { |k,v| v.zero? }
		end

		def counters_blank(moderation_digest)
			moderation_digest.reject { |k,v| reject_blank_values(v).blank? }.blank?
		end
	end
end
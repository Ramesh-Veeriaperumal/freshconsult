namespace :spam_digest_mailer do

	desc "Fetch spam count for an account from dynamo db and dispatch the spam digest email according to the account's timezone"
	task :queue => :environment do
		time_zones = Timezone::Constants::UTC_MORNINGS[Time.zone.now.utc.hour]
		Sharding.execute_on_all_shards do
			Sharding.run_on_slave do
				Account.active_accounts.find_in_batches(
					:batch_size => 500, :conditions => {:time_zone => time_zones}) do |accounts|
					accounts.each do |account|
						forum_spam_digest_recipients = account.forum_moderators.map(&:email).compact
						if account.features_included?(:spam_dynamo) && forum_spam_digest_recipients.present?
							Resque.enqueue(Workers::Community::DispatchSpamDigest, {:account_id => account.id }) 
							puts "** Queued ** #{account} ** for spam digest email **"
						end
					end
				end
			end
		end
	end
end
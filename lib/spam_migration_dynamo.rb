module SpamMigrationDynamo

	class << self
		include SpamPostMethods
		include SpamAttachmentMethods
		include Redis::SpamMigration
		
		def migrate(shard_name)

			Sharding.run_on_shard(shard_name) do
				Sharding.run_on_slave do

					Account.active_accounts.find_in_batches(:batch_size => 100) do |accounts|
						accounts.each do |account|
							next if account.features_included?(:spam_dynamo)
							migrate_for_account(account)
						end
					end
				end
			end
		end

		def account_migrate(account_id)
			Sharding.select_shard_of(account_id) do
				account = Account.find(account_id)
				migrate_for_account(account)
			end
		end

		private

		def migrate_for_account(account)
			p "**** Migration started for account ##{account.id} ****"
			account.make_current
			move_unpublished_topics(account)
			move_unpublished_posts(account)

			create_feature_for_account(account)
			#setting Timestamp for migrated account in Redis
			set_as_migrated(account.id)

			p "**** Completed for account ##{account.id} ****"
			p ""
			Account.reset_current_account
		end

		def move_unpublished_topics(account)
			p "Migrating unpublished topics"
			last_timestamp = 60.days.ago

			while unpublished_topics_count(last_timestamp, account) > 0
				account.topics.where(topic_condition(last_timestamp)).find_in_batches(:batch_size => 100) do |topics|
					topics.each do |topic|
						last_timestamp = topic.created_at
						create_dynamo_post(topic.posts.first)

						print "."
					end
				end
			end
		end

		def move_unpublished_posts(account)
			p "Migrating unpublished posts"
			last_timestamp = 60.days.ago

			while unpublished_posts_count(last_timestamp, account) > 0
				account.posts.where(post_condition(last_timestamp)).joins(:topic).find_in_batches(:batch_size => 100) do |posts|
					posts.each do |post|
						last_timestamp = post.created_at
						create_dynamo_post(post)

						print "."
					end
				end
			end
		end

		def unpublished_topics_count(timestamp, account)
			account.topics.where(topic_condition(timestamp)).count
		end

		def unpublished_posts_count(timestamp, account)
			account.posts.where(post_condition(timestamp)).joins(:topic).count
		end

		def create_feature_for_account(account)
			p "**** Creating Feature ****"
			account.features.spam_dynamo.create
			create_default_forum_moderators(account)
		end

		def create_default_forum_moderators(account)
			admin_privilege = account.roles.find_by_name('Account Administrator').privileges
			account_admins = account.users.where(privileges: admin_privilege)
			account_admins.each do |admin|
				moderator = account.forum_moderators.new
				moderator.user = admin
				moderator.save
			end
		end

		def topic_condition(timestamp)
			['created_at > ? and published = false', timestamp]
		end

		def post_condition(timestamp)
			['posts.created_at > ? and posts.published = false and topics.published = true', timestamp]
		end
	end
end

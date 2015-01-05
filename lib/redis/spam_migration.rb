module Redis::SpamMigration
	include Redis::RedisKeys

	def set_key(key)
		newrelic_begin_rescue do
			$redis_others.set(key, Time.now.utc.to_i)
			$redis_others.expire(key, 60.days.seconds.to_i)
		end 
	end

	def set_as_migrated(account_id)
		set_key(spam_migration_key(account_id))
	end

	def spam_migration_key(account_id)
		SPAM_MIGRATION % { :account_id => account_id }
	end

end

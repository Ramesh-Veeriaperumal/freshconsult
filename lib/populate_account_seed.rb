class PopulateAccountSeed
	
	class << self
		include Redis::RedisKeys
		include Redis::OthersRedis

		def populate_for(account)
			account.make_current
			SeedFu::PopulateSeed.populate_foreground
			if redis_key_exists?(BACKGROUND_FIXTURES_ENABLED)
				account.set_background_fixtures_enqueued
				AccountCreation::PopulateSeedData.perform_async
			else
				SeedFu::PopulateSeed.populate_background
			end
		end
	end
	
end
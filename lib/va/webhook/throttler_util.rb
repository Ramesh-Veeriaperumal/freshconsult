module Va::Webhook::ThrottlerUtil

	include Redis::RedisKeys

	THROTTLE_EVERY = 1.hour.to_i
	THROTTLE_LIMIT = 1000

	private

		def key
			WEBHOOK_THROTTLER % {:account_id => Account.current.id}
		end

end
module Notifications::MessageBroker

	include RedisKeys

	# Maximum nof of feeds the user can have in memory
	USER_FEED_LIMIT = 5

	#Notification types..
	NOTIFICATION_TYPES = { :Feed => "Feed", :Achievement => "Achievement", :Warning => "Warning" }

	#Default notification_badge
	DEFAULT_BADGE = "badges-levelup"

	#Used to put the notifications
	def publish(message, recievers, badge=DEFAULT_BADGE, type=NOTIFICATION_TYPES[:Feed])
		return if recievers.blank? || message.blank?

		message = Notifications::Message.new  message, badge, type
		message_json = message.to_json
		recievers.each do |reciever_id|
			push(reciever_id, message_json)
		end
	end

	#Used to get the notifications 
	def subscribe(count=USER_FEED_LIMIT)
		pull(count)
	end

	private
		def game_notification_key(user_id=User.current.id)
			HELPDESK_GAME_NOTIFICATIONS % { :account_id => Account.current.id, :user_id => user_id}
		end

		def push(reciever_id,message_json)
			key = game_notification_key(reciever_id)
			$redis.lpush(key,message_json)
			$redis.rpop(key) if $redis.llen(key) > USER_FEED_LIMIT
		end

		def pull(count=USER_FEED_LIMIT)
			key = game_notification_key
			total_length = $redis.llen(key)
			results = []
			count = total_length if count > total_length
			count.times do |index|
				results.push($redis.lpop(key))
			end
			results
		end

end
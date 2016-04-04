class RemoveUserEmailRedisKey < ActiveRecord::Migration
	shard :all
	def self.up
		$redis_others.del('user_email_migrated')
	end

	def self.down
	end
end

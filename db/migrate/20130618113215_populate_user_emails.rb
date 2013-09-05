class PopulateUserEmails < ActiveRecord::Migration
  shard :none
  def self.up
  	Account.find_in_batches do |accounts|
  		accounts.each do |account|
  			execute(%(INSERT INTO user_emails (account_id, user_id, email, primary_role, verified, 
      		created_at, updated_at) SELECT account_id, id, email, true, active, now(), now() FROM 
      		users WHERE account_id = #{account.id} and email IS NOT NULL))
        $redis_others.sadd('user_email_migrated', account.id)
  		end
  	end
  end

  def self.down
    $redis_others.del('user_email_migrated')
  end
end

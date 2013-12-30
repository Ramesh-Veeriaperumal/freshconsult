class CleanupCorruptedUsers < ActiveRecord::Migration
  shard :all
  def self.up
  	count = 0
  	User.find_in_batches(:batch_size => 300, 
  		:conditions => ['helpdesk_agent = ? and active = ?', true,true]) do |users|
  		count = count + 1
  		users.each do |user|
  			user.helpdesk_agent = false if user.agent.nil?
  			if user.has_no_credentials?
  				user.account.make_current
  				puts "Id: #{user.id}, Email: #{user.email}, account: #{user.account_id}"
				user.active = false
			end
			user.save if user.changed?
			Account.reset_current_account
  		end
  		puts "Batch #{count} done"
  	end

  	count = 0
  	Agent.find_in_batches(:batch_size => 300, 
  		:joins => "inner join users on users.id = agents.user_id and users.account_id = agents.account_id", 
  		:conditions => ["users.helpdesk_agent = ? ", false]) do |agent|
  		count = count + 1
  		agents.each do |agent|
  			puts "Id: #{agent.user_id}, Email: #{agent.user.email}, account: #{agent.account_id}"
  			agent.destroy
  		end
  		puts "Batch #{count} done"
  	end
  end

  def self.down
  end
end

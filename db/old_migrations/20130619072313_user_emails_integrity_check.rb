class UserEmailsIntegrityCheck < ActiveRecord::Migration
  shard :none
  def self.up
    @error_accounts = []
    @mismatched = []
    Account.find_in_batches do |accounts|
    	accounts.each do |account|
    		user_count = User.count_by_sql(%(SELECT count(id) FROM users WHERE 
    			account_id = #{account.id} AND email IS NOT NULL))
    		user_email_count = UserEmail.count_by_sql(%(SELECT count(id) FROM user_emails WHERE 
    			account_id = #{account.id}))
        user_email_missing = select_all(%(SELECT id FROM users WHERE id NOT IN 
          (SELECT user_id FROM user_emails WHERE account_id=#{account.id}) 
          AND account_id = #{account.id})).collect{|x| x["id"]};
    		user_mismatch = select_all(%(SELECT users.id FROM users LEFT JOIN user_emails ON 
    			users.id = user_emails.user_id AND users.account_id = user_emails.account_id WHERE 
    			users.account_id = #{account.id} AND users.email IS NOT NULL 
          AND users.email <> user_emails.email)).collect{|x| x["id"]}
        @error_accounts << account.id unless (user_count == user_email_count and user_mismatch.empty?)
        @mismatched += user_mismatch
        @mismatched += user_email_missing
    	end
    end

  	if @error_accounts.empty?
      puts "User emails have been populated correctly for all the accounts"
  	else
      puts "There are errors in totally #{@error_accounts.size} accounts"
      puts "The accounts are : #{@error_accounts.inspect}"
      puts "Mismatched users are : #{@mismatched.inspect}"
  	end

  end

  def self.down
  end
end

class PopulateUserEmails < ActiveRecord::Migration
  shard :all
  def self.up
    Account.find_in_batches do |accounts|
      accounts.each do |account|
        account.email_users.find_in_batches do |users|
          account.user_emails.create(users.collect{|x| {:user_id => x.id, 
                                                        :email => x.email, 
                                                        :primary_role => true, 
                                                        :verified => x.active}
                                                  })
        end
        $redis_others.sadd('user_email_migrated', account.id)
      end
    end
  end

  def self.down
    $redis_others.del('user_email_migrated')
  end
end

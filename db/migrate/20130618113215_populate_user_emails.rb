class PopulateUserEmails < ActiveRecord::Migration
  include Redis::RedisKeys
  shard :all
  def self.up
    Account.find_in_batches do |accounts|
      accounts.each do |account|
        account.all_users.find_in_batches(:batch_size => 300, :conditions => ["email is not null"]) do |users|
          account.user_emails.create(users.collect{|x| {:user_id => x.id, 
                                                        :email => x.email, 
                                                        :primary_role => true, 
                                                        :verified => x.active}
                                                  })
        end
        $redis_others.sadd(USER_EMAIL_MIGRATED, account.id)
      end
    end
  end

  def self.down
    $redis_others.del(USER_EMAIL_MIGRATED)
  end
end

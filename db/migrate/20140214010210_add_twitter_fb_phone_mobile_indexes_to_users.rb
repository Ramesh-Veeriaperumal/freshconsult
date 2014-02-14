class AddTwitterFbPhoneMobileIndexesToUsers < ActiveRecord::Migration
  shard :all

  def self.up
    execute <<-SQL
      CREATE INDEX index_users_on_account_id_twitter_id 
      ON users (`account_id`,`twitter_id`)
    SQL
    execute <<-SQL
      CREATE INDEX index_users_on_account_id_fb_profile_id 
      ON users (`account_id`,`fb_profile_id`)
    SQL
    execute <<-SQL
      CREATE INDEX index_users_on_account_id_mobile 
      ON users (`account_id`,`mobile`)
    SQL
    execute <<-SQL
      CREATE INDEX index_users_on_account_id_phone 
      ON users (`account_id`,`phone`)
    SQL
  end

  def self.down

    execute <<-SQL
      DROP INDEX index_users_on_account_id_twitter_id ON users;
    SQL
    execute <<-SQL
      DROP INDEX index_users_on_account_id_fb_profile_id ON users;
    SQL
    execute <<-SQL
      DROP INDEX index_users_on_account_id_mobile ON users;
    SQL
    execute <<-SQL
      DROP INDEX index_users_on_account_id_phone ON users;
    SQL

  end
end



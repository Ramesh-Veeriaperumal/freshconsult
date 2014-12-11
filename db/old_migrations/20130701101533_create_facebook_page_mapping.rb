class CreateFacebookPageMapping < ActiveRecord::Migration
	shard :none
  def self.up
    execute("CREATE TABLE `facebook_page_mappings` (
      `facebook_page_id` bigint(20) NOT NULL,
      `account_id` bigint(20) NOT NULL,
      PRIMARY KEY (`facebook_page_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=latin1;");
  end

  def self.down
  	drop_table :facebook_page_mappings
  end
end

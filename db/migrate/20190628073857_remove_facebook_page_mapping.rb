class RemoveFacebookPageMapping < ActiveRecord::Migration
  shard :none

  def up
    drop_table :facebook_page_mappings
  end

  def down
    execute("CREATE TABLE `facebook_page_mappings` (
      `facebook_page_id` bigint(20) NOT NULL,
      `account_id` bigint(20) NOT NULL,
      PRIMARY KEY (`facebook_page_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=latin1;")
  end
end

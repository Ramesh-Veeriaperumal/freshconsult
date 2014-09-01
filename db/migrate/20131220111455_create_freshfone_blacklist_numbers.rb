class CreateFreshfoneBlacklistNumbers < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :freshfone_blacklist_numbers do |t|
    	t.column  :account_id, "bigint unsigned"
      t.string :number, :limit => 50

      t.timestamps
    end
    add_index :freshfone_blacklist_numbers, [ :account_id, :number ]
  end

  def self.down
    drop_table :freshfone_blacklist_numbers
  end
end

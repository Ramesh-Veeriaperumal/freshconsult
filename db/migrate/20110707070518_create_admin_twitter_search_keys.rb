class CreateAdminTwitterSearchKeys < ActiveRecord::Migration
  def self.up
    create_table :admin_twitter_search_keys do |t|
      t.string :name
      t.string :search_query
      t.integer :twitter_handle_id , :limit => 8
      t.integer :account_id ,  :limit => 8

      t.timestamps
    end
  end

  def self.down
    drop_table :admin_twitter_search_keys
  end
end

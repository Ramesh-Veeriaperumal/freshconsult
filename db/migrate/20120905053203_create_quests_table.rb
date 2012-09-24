class CreateQuestsTable < ActiveRecord::Migration
  def self.up
  	create_table :quests do |t|
      t.column  :account_id, "bigint unsigned"
      t.string  :name
      t.text 	  :description
      t.integer :category
      t.integer :sub_category
      t.boolean :active, :default => true
      t.text    :filter_data
      t.text    :quest_data
      t.integer :points, :default => 0
      t.integer :badge_id
      
      t.timestamps
  	end unless self.table_exists?
  	
  	add_index :quests, [:account_id, :category], :name => 'index_quests_on_account_id_and_category'
  end

  def self.down
  	drop_table :quests
  end

  def self.table_exists?
  	ActiveRecord::Base.connection.table_exists? 'quests'	
  end

end

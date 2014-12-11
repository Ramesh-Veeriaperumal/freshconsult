class CreateAchievedQuests < ActiveRecord::Migration
  def self.up
  	create_table :achieved_quests do |t|
      t.column :user_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
      t.column :quest_id, "bigint unsigned"
      
      t.timestamps
    end
    add_index :achieved_quests, [:user_id, :account_id, :quest_id], :name => 'index_achieved_quests_on_user_id_account_id_quest_id', :unique => true
    add_index :achieved_quests, [:quest_id, :account_id], :name => 'index_achieved_quests_on_quest_id_and_account_id'
  end

  def self.down
  	drop_table :achieved_quests
  end
end

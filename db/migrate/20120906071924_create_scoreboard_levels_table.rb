class CreateScoreboardLevelsTable < ActiveRecord::Migration
  def self.up
    drop_table :scoreboard_levels
    
  	create_table :scoreboard_levels do |t|
      t.column :account_id , "bigint unsigned"
      t.integer  "points"
      t.string   "name"
 
      t.timestamps
    end
    
    add_index :scoreboard_levels, [:account_id], :name => 'index_scoreboard_levels_on_account_id'

  end

  def self.down
  	drop_table :scoreboard_levels
  end
end
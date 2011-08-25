class CreateScoreboardRatings < ActiveRecord::Migration
  def self.up
    create_table :scoreboard_ratings do |t|
      t.integer :account_id, :limit => 8
      t.integer :resolution_speed
      t.integer :score

      t.timestamps
    end
  end

  def self.down
    drop_table :scoreboard_ratings
  end
end

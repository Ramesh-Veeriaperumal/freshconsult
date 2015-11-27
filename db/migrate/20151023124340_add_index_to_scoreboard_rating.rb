class AddIndexToScoreboardRating < ActiveRecord::Migration

	shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :scoreboard_ratings, :atomic_switch => true do |t|
      t.add_index [:account_id, :resolution_speed]
    end
  end

  def down
    Lhm.change_table :scoreboard_ratings, :atomic_switch => true do |t|
      t.remove_index [:account_id, :resolution_speed]
    end
  end
  
end

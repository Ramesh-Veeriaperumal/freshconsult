class AddUserVotesToPosts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :posts, :atomic_switch => true do |m|
      m.add_column :user_votes, "integer DEFAULT '0'"
    end
  end

  def down
    Lhm.change_table :posts, :atomic_switch => true do |m|
      m.remove_column :user_votes
    end
  end
end
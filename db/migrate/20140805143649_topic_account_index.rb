class TopicAccountIndex < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :topics, :atomic_switch => true do |m|
        m.add_index [:account_id, :published, :replied_at]
    end
  end

  def self.down
    Lhm.change_table :topics, :atomic_switch => true do |m|
        m.remove_index [:account_id, :published, :replied_at]
    end
  end
end

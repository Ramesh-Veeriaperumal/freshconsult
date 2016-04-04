class AddRemoveIndexesToPosts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :posts, :atomic_switch => true do |t|
      t.add_index [:account_id, :topic_id, :created_at]
      t.add_index [:account_id, :forum_id]
      t.remove_index [:topic_id]
      t.remove_index [:forum_id]
      t.remove_index [:topic_id, :published]
      t.remove_index [:topic_id, :spam]
    end
  end

  def down
    Lhm.change_table :posts, :atomic_switch => true do |t|
      t.remove_index [:account_id, :topic_id, :created_at]
      t.remove_index [:account_id, :forum_id]
      t.add_index [:topic_id], 'index_posts_on_topic_id'
      t.add_index [:forum_id], 'index_posts_on_forum_id'
      t.add_index [:topic_id, :published], 'index_posts_on_topic_id_and_published'
      t.add_index [:topic_id, :spam], 'index_posts_on_topic_id_and_spam'
    end
  end
end

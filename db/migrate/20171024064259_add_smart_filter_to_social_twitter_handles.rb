class AddSmartFilterToSocialTwitterHandles < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :social_twitter_handles do |m|
      m.add_column :smart_filter_enabled, "boolean"
    end
  end

  def down
   	Lhm.change_table :social_twitter_handles do |m|
      m.remove_column :smart_filter_enabled
    end
  end
end

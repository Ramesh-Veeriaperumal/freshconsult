class AddStampTypeToTopics < ActiveRecord::Migration
  def self.up
    add_column :topics, :stamp_type, :integer
  end

  def self.down
    remove_column :topics, :stamp_type
  end
end

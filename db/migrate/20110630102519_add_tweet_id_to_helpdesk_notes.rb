class AddTweetIdToHelpdeskNotes < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_notes, :tweet_id, :integer , :limit => 8
  end

  def self.down
    remove_column :helpdesk_notes, :tweet_id
  end
end

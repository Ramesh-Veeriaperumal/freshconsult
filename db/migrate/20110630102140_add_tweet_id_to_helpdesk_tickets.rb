class AddTweetIdToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :tweet_id, :integer , :limit => 8
  end

  def self.down
    remove_column :helpdesk_tickets, :tweet_id
  end
end

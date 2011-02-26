class CreateTicketTopics < ActiveRecord::Migration
  def self.up
    create_table :ticket_topics do |t|
      t.integer :ticket_id
      t.integer :topic_id

      t.timestamps
    end
  end

  def self.down
    drop_table :ticket_topics
  end
end

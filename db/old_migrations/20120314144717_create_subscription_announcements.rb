class CreateSubscriptionAnnouncements < ActiveRecord::Migration
  def self.up
    create_table :subscription_announcements do |t|
      t.text :message
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end
  end

  def self.down
    drop_table :subscription_announcements
  end
end

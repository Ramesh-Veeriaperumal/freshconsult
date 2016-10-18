class AddRealtimeMessagingToSocialFacebookPages < ActiveRecord::Migration
	shard :all

	def migrate(direction)
	  self.send(direction)
	end

	def up
	  Lhm.change_table :social_facebook_pages, :atomic_switch => true do |m|
	    m.add_column :realtime_messaging, "tinyint(1) not null  DEFAULT 0"
	  end
	end

	def down
	  Lhm.change_table :social_facebook_pages, :atomic_switch => true do |m|
	    m.remove_column :realtime_messaging
	  end
	end
end

class AddRealtimeSubscriptionSocialFacebookPages < ActiveRecord::Migration
  shard :none
  def self.up
  	execute("alter table social_facebook_pages add column realtime_subscription tinyint(1) not null default 0")
  end

  def self.down
  	execute("alter table social_facebook_pages drop realtime_subscription")
  end
end

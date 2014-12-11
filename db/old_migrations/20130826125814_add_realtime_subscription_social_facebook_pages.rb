class AddRealtimeSubscriptionSocialFacebookPages < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :social_facebook_pages,:atomic_switch => true do |m|
      m.ddl("alter table %s add column realtime_subscription tinyint(1) not null default 0" % m.name)
    end
  end

  def self.down
  	Lhm.change_table :social_facebook_pages,:atomic_switch => true do |m|
      m.ddl("alter table %s drop realtime_subscription" % m.name)
    end
  end
end
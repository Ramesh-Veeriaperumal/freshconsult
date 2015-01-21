class AddBoxToApplications < ActiveRecord::Migration
  shard :all
  def self.up
    box = Integrations::Application.create(
        :name => "box",
        :display_name => "integrations.box.label", 
        :description => "integrations.box.desc", 
        :listing_order => 27,
        :options => { :direct_install => true, 
          :oauth_url => "/auth/box?origin=id%3D{{account_id}}%26portal_id%3D{{portal_id}}%26app_name%3Dbox%26user_id%3D{{user_id}}", 
          :user_specific_auth => true,
          :return_uri => "/integrations/box/choose" },
        :application_type => "box",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    box.save
  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => "box"}).delete
  end
end

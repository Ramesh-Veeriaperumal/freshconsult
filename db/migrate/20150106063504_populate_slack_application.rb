class PopulateSlackApplication < ActiveRecord::Migration
  shard :all
  def self.up
    slack_app = Integrations::Application.create(
        :name => "slack", 
        :display_name => "integrations.slack.label",   
        :description => "integrations.slack.desc",
        :listing_order => 30,
        :options => {
            :keys_order => [:slack_settings], 
            :direct_install => true,
            :slack_settings => { :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", :partial => '/integrations/applications/slack_setting' },
            :configurable => true,
            :oauth_url => '/auth/slack?origin=id%3D{{account_id}}'
            },
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
        :application_type => "slack")
       slack_app.save
  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => "slack"}).delete
  end
end

class AddIlosToApplications < ActiveRecord::Migration
  shard :all

  def up
    Integrations::Application.create(
      :name => "ilos",
      :display_name => "integrations.ilos.label",
      :description => "integrations.ilos.desc",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
      :listing_order => 37,
      :options => {
        :keys_order => [:api_key, :account_settings], 
        :api_key => { :type => :text, :required => true, :label => "integrations.ilos.form.api_key" },
        :account_settings => { 
          :type => :custom, :required => false, :label => "integrations.google_contacts.form.account_settings", 
          :partial => "/integrations/applications/ilosvideos_settings", 
          :info => "integrations.google_contacts.form.account_settings_info" 
        }
      },
      :application_type => "ilos"
    )
  end

  def down
    Integrations::Application.find_by_name("ilos").destroy
  end
end

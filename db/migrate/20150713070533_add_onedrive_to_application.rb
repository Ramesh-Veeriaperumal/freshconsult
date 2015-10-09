class AddOnedriveToApplication < ActiveRecord::Migration
  shard :all
  def up
    onedrive = Integrations::Application.new(
        :name => "onedrive",
        :display_name => "integrations.onedrive.label", 
        :description => "integrations.onedrive.desc", 
        :listing_order => 35,
        :options => { :direct_install => true,           
          :user_specific_auth => true},
        :application_type => "onedrive",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    onedrive.save
  end

  def down
    Integrations::Application.where(:name => "onedrive").first.destroy
  end
end

class PopulateDynamicsCrm < ActiveRecord::Migration
  shard :all
  def up
    dynamics_crm = Integrations::Application.create(
        :name => "dynamicscrm",
        :display_name => "integrations.dynamicscrm.label",
        :description => "integrations.dynamicscrm.desc",
        :listing_order => 31,
        :options => {:direct_install => false},
        :application_type => "dynamicscrm",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
  end

  def down
    execute("DELETE FROM applications WHERE name='dynamicscrm'")
  end
end

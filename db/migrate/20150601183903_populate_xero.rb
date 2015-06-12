class PopulateXero < ActiveRecord::Migration
shard :all
  def up
  	xero = Integrations::Application.create(
      :name => "xero",
      :display_name => "integrations.xero.label",
      :description => "integrations.xero.desc",
      :listing_order => 33,
      :options => {:direct_install => true, :auth_url=> "/integrations/xero/authorize"},
      :application_type => "xero",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
  	execute("DELETE FROM applications WHERE name='xero'")  	
  end
end

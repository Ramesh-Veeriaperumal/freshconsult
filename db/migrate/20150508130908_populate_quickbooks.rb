class PopulateQuickbooks < ActiveRecord::Migration
shard :all
@app_name = "quickbooks"
  def up
    quickbooks = Integrations::Application.create(
      :name => "quickbooks",
      :display_name => "integrations.quickbooks.label",
      :description => "integrations.quickbooks.desc",
      :listing_order => 32,
      :options => {:direct_install => true, :oauth_url => "/auth/quickbooks?origin=id%3D{{account_id}}"},
      :application_type => "quickbooks",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
  	execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end

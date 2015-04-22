class PopulateFive9 < ActiveRecord::Migration
shard :all
@app_name = "five9"
  def up
  	five9 = Integrations::Application.create(
        :name => "five9",
        :display_name => "integrations.five9.label",
        :description => "integrations.five9.desc",
        :listing_order => 31,
        :options => {:direct_install => true},
        :application_type => "cti_integration",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
  end

  def down
  	execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end

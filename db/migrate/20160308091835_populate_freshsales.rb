class PopulateFreshsales < ActiveRecord::Migration
  shard :all
  def up
    freshsales_app = Integrations::Application.create(
      :name => "freshsales",
      :display_name => "integrations.freshsales.label",
      :description => "integrations.freshsales.desc",
      :listing_order => 41,
      :options => { :direct_install => true,
                    :auth_url => "/integrations/freshsales/new",
                    :edit_url => "/integrations/freshsales/edit"
                  },
      :application_type => "freshsales",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
  end

  def down
    execute("DELETE FROM applications WHERE name='freshsales'")
  end
end

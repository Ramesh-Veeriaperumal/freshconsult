class PopulateFullcontact < ActiveRecord::Migration
  shard :all
  def up
    fullcontact = Integrations::Application.create(
        :name => "fullcontact",
        :display_name => "integrations.fullcontact.label",
        :description => "integrations.fullcontact.desc",
        :listing_order => 42,
        :options => {:direct_install => true,
                 :auth_url => "/integrations/fullcontact/new",
                 :edit_url => "/integrations/fullcontact/edit"
                },
        :application_type => "fullcontact",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID,
        :dip => 3 )
  end

  def down
    Integrations::Application.find_by_name("fullcontact").destroy
  end
end

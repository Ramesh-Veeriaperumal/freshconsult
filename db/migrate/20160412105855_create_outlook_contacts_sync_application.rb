class CreateOutlookContactsSyncApplication < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Integrations::Application.create(
      :name => "outlook_contacts",
      :display_name => "integrations.outlook_contacts.label",
      :description => "integrations.outlook_contacts.desc",
      :listing_order => 44,
      :options => {
        :direct_install => true,
        :oauth_url => "/auth/outlook_contacts?origin=id%3D{{account_id}}",
        :edit_url => "/integrations/outlook_contacts/edit"
      },
      :application_type => "outlook_contacts",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID
    )
  end

  def down
    Integrations::Application.find_by_name("outlook_contacts").destroy
  end
end

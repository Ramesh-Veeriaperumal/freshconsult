class AddOauthUrlToGoogleContacts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    app = Integrations::Application.find_by_name("google_contacts")
    app.options[:oauth_url] = "/auth/google_contacts?origin=id%3D{{account_id}}%26app_name%3Dgoogle_contacts%26portal_id%3D{{portal_id}}"
    app.save
  end

  def down
    app = Integrations::Application.find_by_name("google_contacts")
    app.options.delete(:oauth_url)
    app.save
  end
end
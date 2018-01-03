class AddUserSpecificAuthToOffice365 < ActiveRecord::Migration
  shard :all
  def up
    application = Integrations::Application.find_by_name('office365')
    application.options = { direct_install: true, user_specific_auth: true }
    application.save!
  end

  def down
    application = Integrations::Application.find_by_name('office365')
    application.options = { direct_install: true }
    application.save!
  end
end

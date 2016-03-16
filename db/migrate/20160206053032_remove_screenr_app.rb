class RemoveScreenrApp < ActiveRecord::Migration
  shard :all

  def up
    screenr_app = Integrations::Application.find_by_name("screenr")
    Integrations::InstalledApplication.where(:application_id => screenr_app.id).delete_all
    screenr_app.destroy
  end

  def down
    raise "No rollback"
  end
end

class AddApplicationIdAndFilenameToCloudFiles < ActiveRecord::Migration
  shard :all
  def self.up
      Lhm.change_table :helpdesk_dropboxes, :atomic_switch => true do |m|
        m.add_column :application_id, :bigint
        m.add_column :filename, 'varchar(260)'
      end
    dropbox_app_id = Integrations::Application.find_by_name('dropbox').id
    execute("UPDATE helpdesk_dropboxes SET application_id=#{dropbox_app_id} WHERE application_id IS NULL") if dropbox_app_id
  end

  def self.down
    Lhm.change_table :helpdesk_dropboxes, :atomic_switch => true do |m|
      m.remove_column :application_id
      m.remove_column :filename
    end
  end
end
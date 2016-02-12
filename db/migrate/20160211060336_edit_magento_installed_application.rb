class EditMagentoInstalledApplication < ActiveRecord::Migration
  shard :all

  def up
    inst_apps = Integrations::InstalledApplication.with_name("magento").all
    inst_apps.each do |entry|
      entry["configs"]["inputs"]["shops"][0]["admin_url"] = "#{entry["configs"]["inputs"]["shops"][0]["shop_url"]}/admin"
      entry.save!
    end
  end

  def down
    raise "No Rollback"
  end
end

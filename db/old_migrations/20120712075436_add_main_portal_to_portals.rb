class AddMainPortalToPortals < ActiveRecord::Migration
  def self.up
  	add_column :portals, :main_portal, :boolean, :default => false

  	execute("update portals p inner join email_configs e on p.product_id = e.id set p.main_portal = 1, p.product_id = NULL where e.primary_role = 1")
  end

  def self.down
  	remove_column :portals, :main_portal

  	execute("update portals p inner join email_configs e on p.account_id = e.account_id set p.product_id = e.id where e.primary_role = 1")
  end
end

class AddDefaultPortalData < ActiveRecord::Migration
  def self.up
		Account.all.each do |a|
			p = a.portals.build()
			p.name = a.helpdesk_name
			p.portal_url = a.helpdesk_url
			p.product_id = a.primary_email_config.id
			p.preferences = a.preferences
			p.save
		end
  end

  def self.down
  end
end

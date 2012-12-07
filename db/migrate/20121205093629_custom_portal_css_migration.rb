class CustomPortalCssMigration < ActiveRecord::Migration
  def self.up
  	# populating 
  	execute('INSERT INTO portal_templates (account_id,portal_id,created_at,updated_at) SELECT portals.account_id,portals.id, now(), now() from portals')
  end

  def self.down
  	execute<<-SQL
  		TRUNCATEportal_templates
  	SQL
  end
end

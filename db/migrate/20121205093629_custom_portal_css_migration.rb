class CustomPortalCssMigration < ActiveRecord::Migration
  def self.up
  	# populating 
  	execute("INSERT INTO portal_templates (account_id,portal_id,created_at,updated_at,preferences) SELECT portals.account_id,portals.id, now(), now(), CONCAT('--- \n:tab_hover_color: \"#4c4b4b\"\n:btn_primary_background: \"#6c6a6a\"\n:textColor: \"#333333\"\n:btn_background: \"#ffffff\"\n:inputFocusRingColor: \"#f4af1a\"\n:bg_color: \"',SUBSTRING(preferences FROM INSTR(preferences, \"bg_color:\")+11 FOR 7),'\"\n:help_center_color: \"#f9f9f9\"\n:headingsColor: \"#333333\"\n:baseFontFamily: Helvetica Neue\n:headingsFontFamily: Open Sans Condensed\n:header_color: \"',SUBSTRING(preferences FROM INSTR(preferences, \"header_color:\")+15 FOR 7),'\"\n:footer_color: \"#777777\"\n:linkColor: \"#049cdb\"\n:linkColorHover: \"#036690\"\n:tab_color: \"#',SUBSTRING(preferences FROM INSTR(preferences, \"tab_color:\")+12 FOR 7),'\"\n') from portals")
  	execute("create index `index_portals_on_account_id_and_portal_id` on portal_templates (`account_id`,`portal_id`)")
  	execute("create index `index_portals_on_account_id_and_template_id_page_type` on portal_pages (`account_id`,`template_id`,`page_type`)")
  end

  def self.down
  	execute<<-SQL
  		TRUNCATE portal_templates
  	SQL
  	execute("DROP INDEX `index_portals_on_account_id_and_portal_id` on portal_templates")
  	execute("DROP INDEX `index_portals_on_account_id_and_template_id_page_type` on portal_pages")
  end
end

class UpdateJiraTextFormatInInstalledApplications < ActiveRecord::Migration
shard :all

  def self.up
  	execute("update installed_applications set configs=replace(configs,'Freshdesk Ticket # {{ticket.id}} - {{ticket.description_text}}','Freshdesk Ticket # {{ticket.id}} - {{ticket.description_html}}') where application_id=(select id from applications where name='jira')")
  end

  def self.down
  	execute("update installed_applications set configs=replace(configs,'Freshdesk Ticket # {{ticket.id}} - {{ticket.description_html}}','Freshdesk Ticket # {{ticket.id}} - {{ticket.description_text}}') where application_id=(select id from applications where name='jira')")
  end
end

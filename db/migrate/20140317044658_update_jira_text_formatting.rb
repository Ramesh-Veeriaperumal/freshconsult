class UpdateJiraTextFormatting < ActiveRecord::Migration
	shard :all
  @app_name = "jira"


  def self.up
  	jira_app = Integrations::Application.first(:conditions=>["name='#{@app_name}'"])
  	jira_app.options[:jira_note][:default_value]="Freshdesk Ticket # {{ticket.id}} - {{ticket.description_html}}"
  	jira_app.save!
  end

  def self.down
  	jira_app = Integrations::Application.first(:conditions=>["name='#{@app_name}'"])
  	jira_app.options[:jira_note][:default_value]="Freshdesk Ticket # {{ticket.id}} - {{ticket.description_text}}"
  	jira_app.save!

  end
end

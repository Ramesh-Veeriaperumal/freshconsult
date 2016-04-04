class UpdateJiraWidget < ActiveRecord::Migration
  def self.up
    description_text = ', ticketDesc:"{{ticket.description_text}}"'
    execute("UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, '#{description_text}', '') WHERE NAME='jira_widget'")
    execute("UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, '{{ticket.subject}}', '{{ticket.subject | escape_html}}') WHERE NAME='jira_widget'")
  end
 
  def self.down
    description_text = ', ticketDesc:"{{ticket.description_text}}"'
    execute("UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, '{{ticket.raw_id}}', '{{ticket.raw_id}}#{description_text}') WHERE NAME='jira_widget'")
    execute("UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, '{{ticket.subject | escape_html}}', '{{ticket.subject}}') WHERE NAME='jira_widget'")
  end
end

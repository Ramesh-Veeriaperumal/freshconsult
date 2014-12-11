class UpdateJiraCustomFieldName < ActiveRecord::Migration
shard :all

  def self.up
  	execute("update installed_applications set configs =concat(configs,'\n  customFieldName: Freshdesk Tickets') where application_id=(select id from applications where name='jira')")

  end

  def self.down
  	execute("update installed_applications set configs=REPLACE(configs,'customFieldName: Freshdesk Tickets','') where application_id=(select id from applications where name='jira')")
  end
end

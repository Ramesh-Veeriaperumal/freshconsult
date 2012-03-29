class UpdateJiraWidget < ActiveRecord::Migration
  def self.up
  	jira_script = %{
      <div id="jira_widget">
        <div class="content"></div>
      </div>
      <div class="hide" id="jira-note">
        {{jira.jira_note}}
       </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/atlassian-jira.js");
        jiraBundle={domain:"{{jira.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", ticketId:"{{ticket.id}}", ticket_rawId:"{{ticket.raw_id}}", ticketSubject:"{{ticket.subject | escape_html}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}", username:"{{jira.username}}", custom_field_id:"{{jira.customFieldId}}" } ;
      </script>}

    execute("UPDATE widgets SET script = '#{jira_script}' where name='jira_widget'")
  end

  def self.down
  	jira_script = %{
      <div id="jira_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/atlassian-jira.js");
        jiraBundle={domain:"{{jira.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", jiraNote:"{{jira.jira_note | escape_html}}", ticketId:"{{ticket.id}}", ticket_rawId:"{{ticket.raw_id}}", ticketSubject:"{{ticket.subject | escape_html}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}", username:"{{jira.username}}", custom_field_id:"{{jira.customFieldId}}" } ;
      </script>}

    execute("UPDATE widgets SET script = '#{jira_script}' where name='jira_widget'")
  end
end

class PopulateJira < ActiveRecord::Migration
  	  
  @app_name = "jira"
  @widget_name = "jira_widget"
  
  def self.up
    display_name = "integrations.jira.label"  
    description = "integrations.jira.desc"
    listing_order = 5,
    options = {
        :keys_order => [:title, :domain, :username, :password, :jira_note], 
        :title => { :type => :text, :required => true, :label => "integrations.jira.form.widget_title", :default_value => "Atlassian Jira"},
        :domain => { :type => :text, :required => true, :label => "integrations.jira.form.domain", :info => "integrations.jira.form.domain_info", :validator_type => "url_validator" }, 
        :jira_note => { :type => :text, :required => false, :label => "integrations.jira.form.jira_note", 
                            :info => "integrations.jira.form.jira_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}} -- {{ticket.description_text}}' },
        :username => { :type => :text, :required => true, :label => "integrations.jira.form.username" },
        :password => { :type => :password, :required => true, :label => "integrations.jira.form.password" }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, options) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED JIRA APP ID #{app_id}"

    # Add new widget under jira app
    description = "jira.widgets.jira_widget.description"
    script = %{
      <div id="jira_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/atlassian-jira.js");
        jiraBundle={domain:"{{jira.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", jiraNote:"{{jira.jira_note | escape_html}}", ticketId:"{{ticket.id}}", ticketSubject:"{{ticket.subject}}", ticketDesc:"{{ticket.description_text}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}", username:"{{jira.username}}", custom_field_id:"{{jira.customFieldId}}" } ;
       </script>}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
  end

  def self.down
  	execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end

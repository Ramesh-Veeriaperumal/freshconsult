class PopulateWorkflowMax < ActiveRecord::Migration
  @app_name = "workflow_max"
  @widget_name = "workflow_max_timeentry_widget"

  def self.up
    # Add new application called workflow_max
    display_name = "integrations.workflow_max.label"  
    description = "integrations.workflow_max.desc"
    listing_order = 8
    options = {
        :keys_order => [:title, :api_key, :account_key, :workflow_max_note], 
        :title => { :type => :text, :required => true, :label => "integrations.workflow_max.form.widget_title", :default_value => "Workflow MAX"},
        :api_key => { :type => :text, :required => true, :label => "integrations.workflow_max.form.api_key", :info => "integrations.workflow_max.form.api_key_info" },
        :account_key => { :type => :text, :required => true, :label => "integrations.workflow_max.form.account_key", :info => "integrations.workflow_max.form.account_key_info" },
        :workflow_max_note => { :type => :text, :required => false, :label => "integrations.workflow_max.form.workflow_max_note", 
                            :info => "integrations.workflow_max.form.workflow_max_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, listing_order, options) VALUES ('#{@app_name}', '#{display_name}', '#{description}', #{listing_order}, '#{options}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED workflow_max APP ID #{app_id}"

    # Add new widget under workflow_max app
    description = "workflow_max.widgets.timeentry_widget.description"
    script = %{
      <div id="workflow_max_widget" title="{{workflow_max.title}}">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/workflow_max.js");
        workflowMaxBundle={ k:"{{workflow_max.api_key}}", a:"{{workflow_max.account_key}}", api_url:"https://api.workflowmax.com" , application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", workflowMaxNote:"{{workflow_max.workflow_max_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
      </script>}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
  end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end

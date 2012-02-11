class PopulateHarvest < ActiveRecord::Migration
  @app_name = "harvest"
  @widget_name = "harvest_timeentry_widget"

  def self.up
    # Add new application called harvest
    display_name = "integrations.harvest.label"  
    description = "integrations.harvest.desc"
    options = {
        :keys_order => [:title, :domain, :harvest_note], 
        :title => { :type => :text, :required => true, :label => "integrations.harvest.form.widget_title", :default_value => "Harvest"},
        :domain => { :type => :text, :required => true, :label => "integrations.harvest.form.domain", :info => "integrations.harvest.form.domain_info", :rel=> "ghostwriter", :autofill_text => ".harvestapp.com", :validator_type => "domain_validator" }, 
        :harvest_note => { :type => :text, :required => false, :label => "integrations.harvest.form.harvest_note", 
                            :info => "integrations.harvest.form.harvest_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, options) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED HARVEST APP ID #{app_id}"

    # Add new widget under harvest app
    description = "harvest.widgets.timeentry_widget.description"
    script = %{
      <div id="harvest_widget" title="{{harvest.title}}">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/harvest.js");
        harvestBundle={domain:"{{harvest.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", harvestNote:"{{harvest.harvest_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
       </script>}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
  end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end

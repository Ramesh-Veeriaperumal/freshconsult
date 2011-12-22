class PopulateFreshbooks < ActiveRecord::Migration
  @app_name = "freshbooks"
  @widget_name = "freshbooks_timeentry_widget"

  def self.up
    # Add new application called freshbooks
    display_name = "integrations.freshbooks.label"  
    description = "integrations.freshbooks.desc"
    options = {
        :keys_order => [:title, :api_url, :api_key, :freshbooks_note], 
        :title => { :type => :text, :required => true, :label => "integrations.freshbooks.form.widget_title", :default_value => "Freshbooks"},
        :api_url => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_url", :info => "integrations.freshbooks.form.api_url_info" }, 
        :api_key => { :type => :text, :required => true, :label => "integrations.freshbooks.form.api_key", :info => "integrations.freshbooks.form.api_key_info" },
        :freshbooks_note => { :type => :text, :required => false, :label => "integrations.freshbooks.form.freshbooks_note", 
                            :info => "integrations.freshbooks.form.freshbooks_note_info", :default_value => 'Freshdesk Ticket # {{ticket.id}}' }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, options) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED FRESHBOOKS APP ID #{app_id}"

    # Add new widget under freshbooks app
    description = "freshbooks.widgets.timeentry_widget.description"
    script = %{
      <div id="freshbooks_widget" api_url="{{freshbooks.api_url}}" title="{{freshbooks.title}}">
        <div id="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/freshbooks.js");
        freshbooksBundle={ k:"{{freshbooks.api_key}}", freshbooksNote:"{{freshbooks.freshbooks_note | escape_html}}", ticketId:"{{ticket.id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
       </script>}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
  end

  def self.down
    execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end
end

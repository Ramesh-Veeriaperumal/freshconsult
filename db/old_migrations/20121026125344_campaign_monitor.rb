class CampaignMonitor < ActiveRecord::Migration
	@app_name = "campaignmonitor"
  @widget_name = "campaignmonitor_widget"

  def self.up
    display_name = "integrations.campaignmonitor.label"  
    description = "integrations.campaignmonitor.desc"
    listing_order = 14,
    options = {
        :keys_order => [:api_key, :client_id], 
        :api_key => { :type => :text, :required => true, :label => "integrations.campaignmonitor.form.api_key", :info => "integrations.campaignmonitor.form.api_key_info" },
        :client_id => { :type => :text, :required => true, :label => "integrations.campaignmonitor.form.client_id", :info => "integrations.campaignmonitor.form.client_id_info" }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    Rails.logger.debug "INSERTED CampaignMonitor APP ID #{app_id}"

    # Add new widget under salesforce app
    description = "campaignmonitor.widgets.campaignmonitor_widget.description"
    script = %{
      <div id="campaignmonitor_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/campaignmonitor.js");
        cmBundle={reqEmail:"{{requester.email}}", reqName:"{{requester.name}}", api_key:"{{campaignmonitor.api_key}}", client_id:"{{campaignmonitor.client_id}}", export: "{{export}}" } ;
       </script>}
       options = {"display_in_pages" => ["contacts_show_page_side_bar"], "clazz" => "hide"}.to_yaml
       execute("INSERT INTO widgets(name, description, script, application_id, options) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id}, '#{options}')")
  end

  def self.down
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
  end
end

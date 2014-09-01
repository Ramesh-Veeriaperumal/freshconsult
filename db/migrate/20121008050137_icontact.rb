class Icontact < ActiveRecord::Migration
	@app_name = "icontact"
  @widget_name = "icontact_widget"

  def self.up
    display_name = "integrations.icontact.label"  
    description = "integrations.icontact.desc"
    listing_order = 15,
    options = {
        :keys_order => [:api_url, :username, :password], 
        :api_url => { :type => :text, :required => true, :label => "integrations.icontact.form.api_url", :info => "integrations.icontact.form.api_url_info", :validator_type => "url_validator" }, 
        :username => { :type => :text, :required => true, :label => "integrations.icontact.form.username" },
        :password => { :type => :password, :label => "integrations.icontact.form.api_password" }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    Rails.logger.debug "INSERTED iContact APP ID #{app_id}"

    # Add new widget under salesforce app
    description = "icontact.widgets.icontact_widget.description"
    script = %{
      <div id="icontact_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/icontact.js");
        icontactBundle={reqEmail:"{{requester.email}}", reqName:"{{requester.name}}",  app_id:"{{icontact.app_id}}", username:"{{icontact.username}}", api_url:"{{icontact.api_url}}", app_id:"{{icontact.app_id}}", export: "{{export}}"  } ;
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

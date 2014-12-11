class PopulateZohoCrm < ActiveRecord::Migration

@app_name = "zohocrm"
@widget_name = "zohocrm_widget"

  def self.up
    display_name = "integrations.zohocrm.label"  
    description = "integrations.zohocrm.desc"
    listing_order = 18,
    options = {
        :keys_order => [:api_key], 
        :api_key => { :type => :text, :required => true, :label => "integrations.zohocrm.form.api_key", :info => "integrations.zohocrm.form.api_key_info"},
    }.to_yaml

    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED ZOHOCRM APP ID #{app_id}"

    # Add new widget under zohocrm app
    widget_options = {'display_in_pages' => ["contacts_show_page_side_bar"]}.to_yaml
    description = "Zoho CRM widget."
    script = %{
      <div id="zohocrm_widget"  class="integration_widget crm_contact_widget">
        <div class="content"></div>
        <div class="error"></div>
      </div>
      <script type="text/javascript">
        zohocrm_options={ k:"{{zohocrm.api_key}}", reqEmail: "{{requester.email}}", reqName: "{{requester.name | escape_html}}"};
        CustomWidget.include_js("/javascripts/integrations/zohocrm.js");
       </script>
    }

    execute("INSERT INTO widgets(name, description, script, application_id, options) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id}, '#{widget_options}')")

  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
    execute("DELETE FROM widgets WHERE name='#{@widget_name}'")
  end
end

class PopulateSugarcrm < ActiveRecord::Migration

@app_name = "sugarcrm"
@widget_name = "sugarcrm_widget"

  def self.up
  	display_name = "integrations.sugarcrm.label"  
    description = "integrations.sugarcrm.desc"
    listing_order = 7,
    options = {
        :keys_order => [:title, :domain, :username, :password], 
        :title => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.widget_title", :default_value => "SugarCRM"},
        :domain => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.domain", :info => "integrations.sugarcrm.form.domain_info", :validator_type => "url_validator" }, 
        :username => { :type => :text, :required => true, :label => "integrations.sugarcrm.form.username" },
        :password => { :type => :password, :label => "integrations.sugarcrm.form.password" }
    }.to_yaml


    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED SUGARCRM APP ID #{app_id}"

    # Add new widget under sugarcrm app
    description = "sugarcrm.widgets.sugarcrm_widget.description"
    script = %{
      <div id="sugarcrm_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/sugarcrm.js");
        sugarcrmBundle={domain:"{{sugarcrm.domain}}", reqEmail:"{{requester.email}}", username:"{{sugarcrm.username}}", password:"{{sugarcrm.password}}"} ;
       </script>}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
    
  end

  def self.down
  end
end

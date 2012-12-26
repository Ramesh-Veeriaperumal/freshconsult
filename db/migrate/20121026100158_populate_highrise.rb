class PopulateHighrise < ActiveRecord::Migration

@app_name = "highrise"
@widget_name = "highrise_widget"

  def self.up
  	display_name = "integrations.highrise.label"  
    description = "integrations.highrise.desc"
    listing_order = 12,
    options = {
        :keys_order => [:domain, :api_key], 
        :domain => { 	:type => :text,
        				:required => true,
        				:label => "integrations.highrise.form.domain",
        				:info => "integrations.highrise.form.domain_info",
        				#:validator_type => "url_validator",
        				:rel => "ghostwriter",
        				:autofill_text => ".highrisehq.com",
        				:validator_type => "domain_validator"
        			}, 
        :api_key => { :type => :text, :required => true, :label => "integrations.highrise.form.api_key" },
    }.to_yaml

    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED HIGHRISE APP ID #{app_id}"

    # Add new widget under highrise app
    widget_options = {'display_in_pages' => ["contacts_show_page_side_bar"]}.to_yaml
    description = "highrise.widgets.highrise_widget.description"
    script = %{

      <div id="highrise_widget"  class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
	jQuery(document).ready(function(){
        highrise_options={ domain:"{{highrise.domain}}", k:"{{highrise.api_key}}", reqEmail: "{{requester.email}}", reqName: "{{requester.name}}"};
        CustomWidget.include_js("/javascripts/integrations/highrise.js");
	});
       </script>
	}

    execute("INSERT INTO widgets(name, description, script, application_id, options) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id}, '#{widget_options}')")

  end

  def self.down
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
    execute("DELETE FROM widgets WHERE name='#{@widget_name}'")
  end
end

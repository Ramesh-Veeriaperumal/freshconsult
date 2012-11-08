class PopulateBatchbook < ActiveRecord::Migration

@app_name = "batchbook"
@widget_name = "batchbook_widget"
# batchbook made from sugarcrm
  def self.up
  	display_name = "integrations.batchbook.label"  
    description = "integrations.batchbook.desc"
    listing_order = 11,
    options = {
        :keys_order => [:domain, :api_key, :version], 
        :domain => { 	:type => :text,
        				:required => true,
        				:label => "integrations.batchbook.form.domain",
        				:info => "integrations.batchbook.form.domain_info",
        				#:validator_type => "url_validator",
        				:rel => "ghostwriter",
        				:autofill_text => ".batchbook.com",
        				:validator_type => "domain_validator"
        			}, 
        :api_key => { :type => :text, :required => true, :label => "integrations.batchbook.form.api_key" },
        :version => { :type => :dropdown,
                      :choices => ["integrations.batchbook.form.version.classic", "integrations.batchbook.form.version.new"],
                      :css_class => "hide",
                      :required => true,
                      :default_value => "integrations.batchbook.form.version.classic",
                      :label => "integrations.batchbook.form.version.label"
              }
        #:password => { :type => :password, :label => "integrations.batchbook.form.password", :encryption_type => "md5" }
    }.to_yaml


    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED BATCHBOOK APP ID #{app_id}"

    # Add new widget under batchbook app
    description = "batchbook.widgets.batchbook_widget.description"
    script = %{


      <div id="batchbook_widget"  class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
    jQuery(document).ready(function(){
        batchbookBundle={ domain:"{{batchbook.domain}}", k:"{{batchbook.api_key}}", reqEmail: "{{requester.email}}", reqName: "{{requester.name}}"};
        CustomWidget.include_js("/javascripts/integrations/batchbook.js");
    });
       </script>
    
    	}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
    
  end

  def self.down
  end
end

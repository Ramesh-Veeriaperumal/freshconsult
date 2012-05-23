class Salesforce < ActiveRecord::Migration
  @app_name = "salesforce"
  @widget_name = "salesforce_widget"

  def self.up
    salesforce = Integrations::Application.create(
        :name => @app_name,
        :display_name => "integrations.salesforce.label", 
        :description => "integrations.salesforce.desc", 
        :listing_order => 9,
        :options => {:direct_install => true, :oauth_url: "/auth/salesforce?origin={{account_id}}"})
    salesforce.save
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED SALESFORCE APP ID #{app_id}"

    # Add new widget under salesforce app
    description = "salesforce.widgets.salesforce_widget.description"
    script = %{
      <div id="salesforce_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
        <div class="salesforce-name error hide"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/salesforce.js");
        salesforceBundle={domain:"{{salesforce.instance_url}}", reqEmail:"{{requester.email}}", token:"{{salesforce.oauth_token}}" } ;
       </script>}
    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")

  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
  end
end

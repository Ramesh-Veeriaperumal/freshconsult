class PopulateNimble < ActiveRecord::Migration
  @app_name = "nimble"
  @widget_name = "nimble_widget"

  def self.up
    nimble = Integrations::Application.create(
        :name => @app_name,
        :display_name => "integrations.nimble.label", 
        :description => "integrations.nimble.desc", 
        :listing_order => 17,
        :options => {:direct_install => true, :oauth_url => "/auth/nimble?origin={{account_id}}"})
    nimble.save
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED nimble APP ID #{app_id}"

    # Add new widget under nimble app
    description = "nimble.widgets.nimble_widget.description"
    script = %{
      <div id="nimble_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
        <div class="error"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/nimble.js");
        nimbleBundle={domain:"{{nimble.instance_url}}", reqName: "{{requester.name | escape_html}}", reqEmail:"{{requester.email}}", oauth_token:"{{nimble.oauth_token}}" } ;
       </script>}
    display_options = {"display_in_pages" => ["contacts_show_page_side_bar"]}.to_yaml
    execute("INSERT INTO widgets(name, description, script, application_id, options) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id}, '#{display_options}')")
  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
    execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
  end
end

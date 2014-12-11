class Mailchimp < ActiveRecord::Migration
@app_name = "mailchimp"
  @widget_name = "mailchimp_widget"

  def self.up
    mailchimp = Integrations::Application.create(
        :name => @app_name,
        :display_name => "integrations.mailchimp.label", 
        :description => "integrations.mailchimp.desc", 
        :listing_order => 13,
        :options => {:direct_install => true, :oauth_url => "/auth/mailchimp?origin={{account_id}}"})
    mailchimp.save
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    Rails.logger.debug "INSERTED MAILCHIMP APP ID #{app_id}"

    # Add new widget under salesforce app
    description = "mailchimp.widgets.mailchimp_widget.description"
    script = %{
      <div id="mailchimp_widget">
        <div class="error modal_error hide"></div>
        <div class="content"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/mailchimp.js");
        mailchimpBundle={api_endpoint:"{{mailchimp.api_endpoint}}", reqEmail:"{{requester.email}}", reqName:"{{requester.name}}",  token:"{{mailchimp.oauth_token}}", export: "{{export}}"  } ;
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

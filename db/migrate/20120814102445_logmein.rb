class Logmein < ActiveRecord::Migration
	@app_name = "logmein"
    @widget_name = "logmein_widget"
  
  def self.up
    display_name = "integrations.logmein.label"  
    description = "integrations.logmein.desc"
    listing_order = 10,
    options = {
        :keys_order => [:title, :company_id, :password], 
        :title => { :type => :text, :required => true, :label => "integrations.logmein.form.widget_title", :default_value => "LogMeIn Rescue"},
        :company_id => { :type => :text, :required => true, :label => "integrations.logmein.form.company_id", :info => "integrations.logmein.form.logmein_company_info" },
        :password => { :type => :password, :label => "integrations.logmein.form.password", :info => "integrations.logmein.form.logmein_sso_pwd_info" }
    }.to_yaml
    execute("INSERT INTO applications(name, display_name, description, options, listing_order) VALUES ('#{@app_name}', '#{display_name}', '#{description}', '#{options}', '#{listing_order}')")
    res = execute("SELECT id FROM applications WHERE name='#{@app_name}'")
    res.data_seek(0)
    app_id = res.fetch_row[0]
    puts "INSERTED LOGMEIN APP ID #{app_id}"

    # Add new widget under logmein app
    description = "logmein.widgets.logmein_widget.description"
    script = %{
        <div class="logmein-logo"><h3 class="title">{{logmein.title}} </h3></div>
        <div id="logmein_widget">
          <div class="content"></div>
          <div class="error hide"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/logmein.js");
        logmeinBundle={ticketId:"{{ticket.id}}", installed_app_id:"{{installed_app_id}}", agentId:"{{agent.id}}", accountId: "{{account_id}}", reqName:"{{requester.name}}", secret:"{{md5secret}}", pincode:"{{cache.pincode}}", pinTime:"{{cache.pintime}}", ssoId:"{{agent.email}}", companyId:"{{logmein.company_id}}", authcode:"{{logmein.authcode}}"} ;
       </script>}

    execute("INSERT INTO widgets(name, description, script, application_id) VALUES ('#{@widget_name}', '#{description}', '#{script}', #{app_id})")
  end

  def self.down
    execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
  	execute("DELETE widgets FROM widgets INNER JOIN applications ON widgets.APPLICATION_ID=applications.ID WHERE widgets.name='#{@widget_name}'")
    execute("DELETE FROM applications WHERE name='#{@app_name}'")
  end

end

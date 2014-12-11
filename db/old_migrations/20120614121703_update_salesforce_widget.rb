class UpdateSalesforceWidget < ActiveRecord::Migration
  def self.up
  	script = %{
      <div id="salesforce_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
        <div class="salesforce-name error hide"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/salesforce.js");
        salesforceBundle={domain:"{{salesforce.instance_url}}", reqEmail:"{{requester.email}}", token:"{{salesforce.oauth_token}}", contactFields:"{{salesforce.contact_fields}}", leadFields:"{{salesforce.lead_fields}}", reqName:"{{requester.name}}"} ;
      </script>}

    execute("UPDATE widgets SET script = '#{script}' where name='salesforce_widget'")
  end

  def self.down
  	script = %{
      <div id="salesforce_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
        <div class="salesforce-name error hide"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/salesforce.js");
        salesforceBundle={domain:"{{salesforce.instance_url}}", reqEmail:"{{requester.email}}", token:"{{salesforce.oauth_token}}" } ;
      </script>}

    execute("UPDATE widgets SET script = '#{script}' where name='salesforce_widget'")
  end
end

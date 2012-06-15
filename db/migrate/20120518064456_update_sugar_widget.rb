class UpdateSugarWidget < ActiveRecord::Migration
  def self.up
  	sugar_script = %{
  		<div id="sugarcrm_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
		<div class="error name hide"></div>
        </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/sugarcrm.js");
        sugarcrmBundle={domain:"{{sugarcrm.domain}}", reqEmail:"{{requester.email}}", username:"{{sugarcrm.username}}", password:"{{sugarcrm.password}}"} ;
       </script>
    }
    execute("UPDATE widgets SET script = '#{sugar_script}' where name='sugarcrm_widget'")
  end

  def self.down
  	sugar_script = %{
      <div id="sugarcrm_widget" class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/sugarcrm.js");
        sugarcrmBundle={domain:"{{sugarcrm.domain}}", reqEmail:"{{requester.email}}", username:"{{sugarcrm.username}}", password:"{{sugarcrm.password}}"} ;
       </script>}

    execute("UPDATE widgets SET script = '#{sugar_script}' where name='sugarcrm_widget'")
  end
end

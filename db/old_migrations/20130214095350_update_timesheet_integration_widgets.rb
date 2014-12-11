class UpdateTimesheetIntegrationWidgets < ActiveRecord::Migration
	def self.up
  	freshbooks_script = %{
      <div id="freshbooks_widget" api_url="{{freshbooks.api_url}}" title="{{freshbooks.title}}">
        <div class="content"></div>
      </div>
      <div class="hide" id="freshbooks-note" >{{freshbooks.freshbooks_note}}</div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/freshbooks.js");
        freshbooksBundle={ k:"{{freshbooks.api_key}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
      </script>
    }
	  harvest_script = %{
	    <div id="harvest_widget" title="{{harvest.title}}">
       <div class="content"></div>
      </div>
      <div class="hide" id="harvest-note" >{{harvest.harvest_note}}</div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/harvest.js");
        harvestBundle={domain:"{{harvest.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
      </script>
	  }
    workflowmax_script = %{
      <div id="workflow_max_widget" title="{{workflow_max.title}}">
        <div class="content"></div>
      </div>
      <div class="hide" id="workflowmax-note" >{{workflow_max.workflow_max_note}}</div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/workflow_max.js");
        workflowMaxBundle={ k:"{{workflow_max.api_key}}", a:"{{workflow_max.account_key}}", api_url:"https://api.workflowmax.com" , application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
      </script>
    }

    execute("UPDATE widgets SET script = '#{freshbooks_script}' where name='freshbooks_timeentry_widget'")
    execute("UPDATE widgets SET script = '#{harvest_script}' where name='harvest_timeentry_widget'")
    execute("UPDATE widgets SET script = '#{workflowmax_script}' where name='workflow_max_timeentry_widget'")
  end

  def self.down
  	freshbooks_script = %{
      <div id="freshbooks_widget" api_url="{{freshbooks.api_url}}" title="{{freshbooks.title}}">
      	<div class="content"></div>
    	</div>
    	<script type="text/javascript">
	      CustomWidget.include_js("/javascripts/integrations/freshbooks.js");
	      freshbooksBundle={ k:"{{freshbooks.api_key}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", freshbooksNote:"{{freshbooks.freshbooks_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
     	</script>
    }
	  harvest_script = %{
	    <div id="harvest_widget" title="{{harvest.title}}">
      	<div class="content"></div>
    	</div>
    	<script type="text/javascript">
	      CustomWidget.include_js("/javascripts/integrations/harvest.js");
	      harvestBundle={domain:"{{harvest.domain}}", application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", harvestNote:"{{harvest.harvest_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
     	</script>

	  }
    workflowmax_script = %{
      <div id="workflow_max_widget" title="{{workflow_max.title}}">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        CustomWidget.include_js("/javascripts/integrations/workflow_max.js");
        workflowMaxBundle={ k:"{{workflow_max.api_key}}", a:"{{workflow_max.account_key}}", api_url:"https://api.workflowmax.com" , application_id:"{{application.id}}", integrated_resource_id:"{{integrated_resource.id}}", remote_integratable_id:"{{integrated_resource.remote_integratable_id}}", workflowMaxNote:"{{workflow_max.workflow_max_note | escape_html}}", ticketId:"{{ticket.display_id}}", agentEmail:"{{agent.email}}", reqEmail:"{{requester.email}}"};
      </script>
    }

    execute("UPDATE widgets SET script = '#{freshbooks_script}' where name='freshbooks_timeentry_widget'")
    execute("UPDATE widgets SET script = '#{harvest_script}' where name='harvest_timeentry_widget'")
    execute("UPDATE widgets SET script = '#{workflowmax_script}' where name='workflow_max_timeentry_widget'")
  end
end

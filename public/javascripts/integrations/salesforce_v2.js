var SalesforceV2Widget = Class.create();
(function($){
	SalesforceV2Widget.prototype= {
		initialize:function(salesforceV2Bundle){
			$("#salesforce_v2_contacts_widget").addClass('loading-fb');
			salesforceV2Widget = this;
			salesforceV2Bundle.app_name = "salesforce_v2";
			salesforceV2Bundle.integratable_type = "crm";
			salesforceV2Bundle.auth_type = "NoAuth";
			salesforceV2Bundle.widget_name = "salesforce_v2_contacts_widget";
			salesforceV2Bundle.handleRender = true;
			//Order, Contract, Opportunity Fields that will be shown as headers, will be needed in resourceSectionTemplate method.
			salesforceV2Bundle.headerFields = ["Name", "OrderNumber", "ContractNumber"];
			salesforceV2Bundle.nameKeyFields = {"Account" : "Name", "Contact" :"Name", "Lead" :"Name", "Opportunity": "Name", "Order" : "OrderNumber", "Contract": "ContractNumber"};
			this.salesforceV2Bundle = salesforceV2Bundle;
			this.contactInfo = this.mapFieldLabels(salesforceV2Bundle.contactFields,salesforceV2Bundle.contactLabels);
			this.leadInfo = this.mapFieldLabels(salesforceV2Bundle.leadFields,salesforceV2Bundle.leadLabels);
			this.accountInfo = this.mapFieldLabels(salesforceV2Bundle.accountFields,salesforceV2Bundle.accountLabels);
			this.opportunityInfo = this.mapFieldLabels(salesforceV2Bundle.opportunityFields,salesforceV2Bundle.opportunityLabels);
			this.contractInfo = this.mapFieldLabels(salesforceV2Bundle.contractFields,salesforceV2Bundle.contractLabels);
			this.orderInfo = this.mapFieldLabels(salesforceV2Bundle.orderFields,salesforceV2Bundle.orderLabels);
			this.initOpportunityContractOrderHash();
			this.fieldsHash = {"Contact": salesforceV2Bundle.contactFields, "Account": salesforceV2Bundle.accountFields, "Lead": salesforceV2Bundle.leadFields};
			freshdeskWidget = new Freshdesk.CRMCloudWidget(salesforceV2Bundle, this);
		},
		mapFieldLabels: function(fields,labels){
			var fieldLabels ={}
			var labelsArr = [];
			fieldsArr = fields.split(",");
			labelsArr = fieldsArr;//no labels until reenabled,defaults to field-name for existing sf users
			if(labels != undefined && labels.length != 0){
				labelsArr = labels.split(",");
			}
			for (var i=0;i<fieldsArr.length;i++){
				fieldLabels[fieldsArr[i]] = labelsArr[i];
			}
			return fieldLabels;
		},
		resetBundle:function(salesforceV2Bundle, email){
			var newSalesforceBundle = {};
			var bundleProperties = ["domain","ticket_id","reqCompany","reqEmails",
											"contactFields","opportunityFields","accountFields",
											"contactLabels","opportunityLabels","accountLabels",
											"leadLabels","leadFields","reqName","contractFields",
											"contractLabels","orderFields","orderLabels","ticket_company",
											"opportunityView","orderView","contractView"
											];
			for(i=0;i<bundleProperties.length;i++){
				newSalesforceBundle[bundleProperties[i]] = salesforceV2Bundle[bundleProperties[i]];
			}
			newSalesforceBundle.reqEmail = email;
			new SalesforceV2Widget(newSalesforceBundle);
		},
		initOpportunityContractOrderHash:function(){
			this.salesforceV2Bundle.opportunityHash = {};
			this.salesforceV2Bundle.contractHash = {};
			this.salesforceV2Bundle.orderHash = {};
		}
	}
}(window.jQuery));

	//update widgets inner join applications on applications.id = widgets.application_id set script=replace(script, " token:", "oauth_token:") where applications.name="salesforce";

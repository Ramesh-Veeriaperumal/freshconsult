var DynamicsV2Widget = Class.create();
(function($){
	DynamicsV2Widget.prototype= {
		initialize:function(dynamicsV2Bundle){
			$("#dynamics_v2_contacts_widget").addClass('loading-fb');
			dynamicsV2Widget = this;
			dynamicsV2Bundle.app_name = "dynamics_v2";
			dynamicsV2Bundle.integratable_type = "crm";
			dynamicsV2Bundle.auth_type = "NoAuth";
			dynamicsV2Bundle.widget_name = "dynamics_v2_contacts_widget";
			dynamicsV2Bundle.handleRender = true;
			//Fields that will be shown as headers will be needed in resourceSectionTemplate method.
			dynamicsV2Bundle.headerFields = ["attributes.name", "attributes.fullname", "attributes.title"] //Order, Account, Opportunity are name, Contact and Lead are fullname, Contract is title.
			dynamicsV2Bundle.nameKeyFields = {"Account" : "attributes.name", "Contact" : "attributes.fullname", "Lead" : "attributes.fullname",  "Opportunity": "attributes.name", "Order" : "attributes.name", "Contract": "attributes.title"};
			//Needed for generating links for dynamics entities
			dynamicsV2Bundle.objects = {"Contact": "contact", "Account" : "account", "Lead" : "lead", "Opportunity" : "opportunity", "Contract" : "contract", "Order" : "salesorder"}
			this.dynamicsV2Bundle = dynamicsV2Bundle;
			this.contactInfo = this.mapFieldLabels(dynamicsV2Bundle.contactFields,dynamicsV2Bundle.contactLabels);
			this.leadInfo = this.mapFieldLabels(dynamicsV2Bundle.leadFields,dynamicsV2Bundle.leadLabels);
			this.accountInfo = this.mapFieldLabels(dynamicsV2Bundle.accountFields,dynamicsV2Bundle.accountLabels);
			this.opportunityInfo = this.mapFieldLabels(dynamicsV2Bundle.opportunityFields,dynamicsV2Bundle.opportunityLabels);
			this.contractInfo = this.mapFieldLabels(dynamicsV2Bundle.contractFields,dynamicsV2Bundle.contractLabels);
			this.orderInfo = this.mapFieldLabels(dynamicsV2Bundle.orderFields,dynamicsV2Bundle.orderLabels);
			this.initOpportunityContractOrderHash();
			this.fieldsHash = {"Contact": dynamicsV2Bundle.contactFields, "Account": dynamicsV2Bundle.accountFields, "Lead": dynamicsV2Bundle.leadFields};
			freshdeskWidget = new Freshdesk.CRMCloudWidget(dynamicsV2Bundle, this);
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
		resetBundle:function(dynamicsV2Bundle, email){
			var newDynamicsBundle = {};
			var bundleProperties = ["domain","ticket_id","reqCompany","reqEmails",
											"contactFields","opportunityFields","accountFields",
											"contactLabels","opportunityLabels","accountLabels",
											"leadLabels","leadFields","reqName","contractFields",
											"contractLabels","orderFields","orderLabels","ticket_company",
											"opportunityView","orderView","contractView"
											];
			for(i=0;i<bundleProperties.length;i++){
				newDynamicsBundle[bundleProperties[i]] = dynamicsV2Bundle[bundleProperties[i]];
			}
			newDynamicsBundle.reqEmail = email;
			new DynamicsV2Widget(newDynamicsBundle);
		},
		initOpportunityContractOrderHash:function(){
			this.dynamicsV2Bundle.opportunityHash = {};
			this.dynamicsV2Bundle.contractHash = {};
			this.dynamicsV2Bundle.orderHash = {};
		}
	}
}(window.jQuery));

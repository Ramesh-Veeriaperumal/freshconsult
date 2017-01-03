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
			salesforceV2Bundle.handleCRMResource = true;
			salesforceV2Bundle.getTemplate = true;
			this.salesforceV2Bundle = salesforceV2Bundle;
			this.contactFields = ["Name"];
			this.leadFields=["Name"];
			this.accountFields=["Name"];
			this.opportunityFields = ["Name"];
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
		get_contact_request: function() {
			var requestUrls = [];
			var custEmail = this.salesforceV2Bundle.reqEmail;
			requestUrls.push({type:"contact", value:custEmail});
			requestUrls.push({type:"lead", value:custEmail});
			var custCompany = this.salesforceV2Bundle.reqCompany;
			var ticket_company = salesforceV2Bundle.ticket_company;
			if( this.salesforceV2Bundle.accountFields && this.salesforceV2Bundle.accountFields.length > 0 ) {
				if(ticket_company && ticket_company.length > 0){ // fetch account by ticket filed company
					requestUrls.push({type:"account", value:{company:ticket_company}});
				}
				else if ( custCompany  && custCompany.length > 0 ) {
					custCompany = custCompany.trim(); 
					requestUrls.push({type:"account", value:{company:custCompany}});
				}
				else{
					requestUrls.push({type:"account", value:{email:custEmail}});
				}
			}
			for(var i=0;i<requestUrls.length;i++){
				requestUrls[i] = {  
					event:"fetch_user_selected_fields", 
					source_url:"/integrations/sync/crm/fetch",
					app_name:"salesforce_v2",
					payload: JSON.stringify(requestUrls[i]) 
				}
			}
			return requestUrls; 
		},
		getTemplate:function(eval_params,crmWidget){
			var resourceTemplate = "";
			var fields;
			var labels;
			switch(eval_params.type){
				case "Lead":
					fields = this.salesforceV2Bundle.leadFields.split(",");
					labels = this.leadInfo;
					resourceTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
				break;
				case "Account":
					fields = this.salesforceV2Bundle.accountFields.split(",");
					labels = this.accountInfo;
					var accountsTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
					var opportunity_records = this.salesforceV2Bundle.opportunityHash[eval_params.Id];
					var contract_records = this.salesforceV2Bundle.contractHash[eval_params.Id];
					var order_records = this.salesforceV2Bundle.orderHash[eval_params.Id];
					resourceTemplate = accountsTemplate;
					if(opportunity_records && salesforceV2Bundle.opportunityView == "1"){
						if(opportunity_records.length){
							resourceTemplate += this.getOpportunitiesTemplate(opportunity_records,eval_params,crmWidget);
						}
						else{
							resourceTemplate += this.getEmptyOpportunitiesTemplate(eval_params,crmWidget);
						}
					}
					if(contract_records && salesforceV2Bundle.contractView == "1"){
						if(contract_records.length){
							resourceTemplate += this.getContractsTemplate(contract_records,eval_params,crmWidget);
						}
						else{
							resourceTemplate += this.getEmptyContractsTemplate(eval_params,crmWidget);
						}
					}
					if(order_records && salesforceV2Bundle.orderView == "1"){
						if(order_records.length){
							resourceTemplate += this.getOrdersTemplate(order_records,eval_params,crmWidget);
						}
						else{
							resourceTemplate += this.getEmptyOrdersTemplate(eval_params,crmWidget);
						}
					}
				break;
				case "Contact":
					labels = this.contactInfo;
					fields = this.salesforceV2Bundle.contactFields.split(",");
					resourceTemplate = this.resourceSectionTemplate(fields,labels,eval_params);
				break;
				default:
			}
			return resourceTemplate;
		},
		resourceSectionTemplate:function(fields,labels,eval_params){
			var contactTemplate ="";
			for(var i=0;i<fields.length;i++){
				var value = eval_params[fields[i]];
				if(fields[i]=="Name" && eval_params.type != "Opportunity"){
				    continue;
				}
				// Placing external link in the name field of opportunity
				else if((fields[i]=="Name" && eval_params.type == "Opportunity") || (fields[i]=="OrderNumber" && eval_params.type == "Order") || (fields[i]=="ContractNumber" && eval_params.type == "Contract")){
					var opp_external_link = salesforceV2Bundle.domain+"/"+eval_params.Id;
					contactTemplate += _.template(this.OPPORTUNITY_TEMPLATE, {opp_external_link: opp_external_link, value: value, label: labels[fields[i]], field: fields[i]});
					continue;
				}
				value = value || "N/A";
				contactTemplate += _.template(this.COMMON_CONTACT_TEMPLATE, {value: value, label: labels[fields[i]], field: fields[i]});
			}
			if(eval_params.type == "Opportunity" ||eval_params.type == "Contract" || eval_params.type == "Order"){ // list of user selected fields, hidden at first
			 	contactTemplate = _.template('<div class="opportunity_details mt5 ml12 hide"><%=contactTemplate%></div>',{contactTemplate:contactTemplate});
			}
			return contactTemplate;
		},
		processSingleResult:function(contact,crmWidget,cloudobj){
			if(contact.type == "Account"){ 
				//This will render single account and it also triggers related opportunities, contracts, orders
				this.account_related_calls_received = 0;
				if(salesforceV2Bundle.opportunityView == "1"){
				    this.account_related_calls_received++;
				    this.getRelatedOpportunities(contact,crmWidget,cloudobj); 
				}
				if(salesforceV2Bundle.contractView == "1"){
				    this.account_related_calls_received++;
				    this.getRelatedContracts(contact,crmWidget,cloudobj);
				}
				if(salesforceV2Bundle.orderView == "1"){
				    this.account_related_calls_received++;
				    this.getRelatedOrders(contact,crmWidget,cloudobj);
				}
				if(this.account_related_calls_received == 0){
					cloudobj.renderContactWidget(contact,crmWidget);  					
				}
			}
			else{
				cloudobj.renderContactWidget(contact,crmWidget);
			}
		},
		loadIntegratedRemoteResource:function(){
			freshdeskWidget.request({
				event:"integrated_resource", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:"salesforce_v2",
				payload: JSON.stringify({ ticket_id:salesforceV2Bundle.ticket_id }),
				on_success: function(response){
				    response = response.responseJSON;
				    if(!_.isEmpty(response)){
				        salesforceV2Bundle.remote_integratable_id = response.remote_integratable_id;
				    }
				    else{
				        salesforceV2Bundle.remote_integratable_id = "";
				    }
				},
				on_failure: function(response){} 
			});
		},
		getRelatedOpportunities:function(eval_params,crmWidget,cloudobj,linkFlag){
			this.showLoadingIcon(crmWidget.options.widget_name);
			var _this = this;
			freshdeskWidget.request({
				event:"fetch_user_selected_fields", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:"salesforce_v2",
				payload: JSON.stringify({ type:"opportunity", value:{ account_id:eval_params.Id }, ticket_id:salesforceV2Bundle.ticket_id }),
				on_success: function(response){
					response = response.responseJSON
					_this.loadOpportunities(response,eval_params,crmWidget,cloudobj,linkFlag);
				},
				on_failure: function(response){
					var message = "Problem occured while fetching opportunties";
					_this.processFailure(eval_params,crmWidget,message,cloudobj);
				} 
			});
		},
		loadOpportunities:function(response,eval_params,crmWidget,cloudobj,linkFlag){
			var opp_records = response.records;
			var error;
			if(opp_records.length > 0){
				var opp_fields = this.salesforceV2Bundle.opportunityFields.split(",");
				for(i=0;i<opp_records.length;i++){
					for(j=0;j<opp_fields.length;j++){
						if(typeof opp_records[i][opp_fields[j]] == "boolean"){
						    continue;
						}
						opp_records[i][opp_fields[j]] = escapeHtml(cloudobj.eliminateNullValues(opp_records[i][opp_fields[j]]));
						if(opp_fields[j] == "CloseDate"){ //Converting close date to user readable format
						    opp_records[i][opp_fields[j]] = new Date(opp_records[i][opp_fields[j]]).toString("dd MMM, yyyy");
				        }
					}
				}
				this.salesforceV2Bundle.opportunityHash[eval_params.Id] = opp_records;
			}
			else{
				this.salesforceV2Bundle.opportunityHash[eval_params.Id] = [];
			}
			if(eval_params.error){ // This will show error in the opportunities section
				error = eval_params.error;
				eval_params.error = undefined;
				this.processFailure(eval_params,crmWidget,error,cloudobj);
			}else{
				if(--this.account_related_calls_received == 0){
					cloudobj.renderContactWidget(eval_params,crmWidget);
				}
			}
		},
		getRelatedContracts:function(eval_params,crmWidget,cloudobj){
			this.showLoadingIcon(crmWidget.options.widget_name);
			var _this = this;
			freshdeskWidget.request({
    		    event:"fetch_user_selected_fields", 
    		    source_url:"/integrations/sync/crm/fetch",
    		    app_name:"salesforce_v2",
    		    payload: JSON.stringify({ type:"contract", value:{ account_id:eval_params.Id } }),
    		    on_success: function(response){
    		    	response = response.responseJSON
    		    	_this.loadContracts(response,eval_params,crmWidget,cloudobj);
    		    },
    		    on_failure: function(response){
    		    	var message = "Problem occured while fetching contracts";
    		    	_this.processFailure(eval_params,crmWidget,message,cloudobj);
    		    } 
			});
		},
		loadContracts:function(response,eval_params,crmWidget,cloudobj){
			var contract_records = response.records;
			var error;
			if(contract_records.length > 0){
				var contract_fields = this.salesforceV2Bundle.contractFields.split(",");
				for(i=0;i<contract_records.length;i++){
					for(j=0;j<contract_fields.length;j++){
						if(typeof contract_records[i][contract_fields[j]] == "boolean"){
							continue;
						}
						contract_records[i][contract_fields[j]] = escapeHtml(cloudobj.eliminateNullValues(contract_records[i][contract_fields[j]]));
						if(contract_fields[j] == "StartDate"){ //Converting start date to user readable format
							contract_records[i][contract_fields[j]] = new Date(contract_records[i][contract_fields[j]]).toString("dd MMM, yyyy");
						}
					}
				}
				this.salesforceV2Bundle.contractHash[eval_params.Id] = contract_records;
			}
			else{
				this.salesforceV2Bundle.contractHash[eval_params.Id] = [];
			}
			if(eval_params.error){ // This will show error in the contract section
				error = eval_params.error;
				eval_params.error = undefined;
				this.processFailure(eval_params,crmWidget,error,cloudobj);
			}else{
				if(--this.account_related_calls_received == 0){
					cloudobj.renderContactWidget(eval_params,crmWidget);
				}
			}
		},
		getRelatedOrders:function(eval_params,crmWidget,cloudobj){
			this.showLoadingIcon(crmWidget.options.widget_name);
			var _this = this;
			freshdeskWidget.request({
				event:"fetch_user_selected_fields", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:"salesforce_v2",
				payload: JSON.stringify({ type:"order", value:{ account_id:eval_params.Id } }),
				on_success: function(response){
					response = response.responseJSON
					_this.loadOrders(response,eval_params,crmWidget,cloudobj);
				},
				on_failure: function(response){
					var message = "Problem occured while fetching orders";
					_this.processFailure(eval_params,crmWidget,message,cloudobj);
				} 
			});
		},
		loadOrders:function(response,eval_params,crmWidget,cloudobj){
			var order_records = response.records;
			var error=undefined;
			if(order_records.length > 0){
				var order_fields = this.salesforceV2Bundle.orderFields.split(",");
				for(i=0;i<order_records.length;i++){
					for(j=0;j<order_fields.length;j++){
						if(typeof order_records[i][order_fields[j]] == "boolean"){
							continue;
						}
						order_records[i][order_fields[j]] = escapeHtml(cloudobj.eliminateNullValues(order_records[i][order_fields[j]]));
						if(order_fields[j] == "EffectiveDate"){ //Converting start date to user readable format
							order_records[i][order_fields[j]] = new Date(order_records[i][order_fields[j]]).toString("dd MMM, yyyy");
						}
					}
				}
				this.salesforceV2Bundle.orderHash[eval_params.Id] = order_records;
			}
			else{
				this.salesforceV2Bundle.orderHash[eval_params.Id] = [];
			}
			if(eval_params.error){ // This will show error in the order section
				error = eval_params.error;
				eval_params.error = undefined;
				this.processFailure(eval_params,crmWidget,error,processFailure);
			}
			else{
				if(--this.account_related_calls_received == 0){
					cloudobj.renderContactWidget(eval_params,crmWidget);					
				}
			}
		},
		getContractsTemplate:function(contract_records,eval_params,crmWidget){
			var contracts_template = "";
			for(var i=0;i<contract_records.length;i++){
				contracts_template += this.getContractDetailsTemplate(contract_records[i]);
			}
			contracts_template = JST["app/integrations/salesforce_v2/object_search_results"]({resultsData:contracts_template, object_name: "Contracts", object_field: "contracts"});
			return contracts_template;
		},
		getContractDetailsTemplate:function(contract_record){
			var contract_template = "";
			var contract_list_item = "";
			contract_record["type"] = "Contract";
			contract_template += '<li><a class="multiple-contracts salesforce-opportunity-tooltip" title="'+contract_record.ContractNumber+'" href="#">'+contract_record.ContractNumber+'</a>'+contract_list_item+'</li>';
			contract_template += this.resourceSectionTemplate(this.salesforceV2Bundle.contractFields.split(","),this.contractInfo,contract_record);
			return contract_template;
		},
		getOrdersTemplate:function(order_records,eval_params,crmWidget){
			var orders_template = "";
			for(var i=0;i<order_records.length;i++){
				orders_template += this.getOrderDetailsTemplate(order_records[i]);
			}
			orders_template = JST["app/integrations/salesforce_v2/object_search_results"]({resultsData:orders_template, object_name: "Orders", object_field: "orders"});
			return orders_template;
		},
		getOrderDetailsTemplate:function(order_record){
			var order_template = "";
			var order_list_item = "";
			order_record["type"] = "Order";
			order_template += '<li><a class="multiple-orders salesforce-opportunity-tooltip" title="'+order_record.OrderNumber+'" href="#">'+order_record.OrderNumber+'</a>'+order_list_item+'</li>';
			order_template += this.resourceSectionTemplate(this.salesforceV2Bundle.orderFields.split(","),this.orderInfo,order_record);
			return order_template;
		},
		getOpportunitiesTemplate:function(opportunity_records,eval_params,crmWidget){
			var opportunities_template = "";
			for(var i=0;i<opportunity_records.length;i++){
				opportunities_template += this.getOpportunityDetailsTemplate(opportunity_records[i]);
			}
			var opportunity = this.getOpportunityCreateTemplate(eval_params);
			opportunities_template = _.template(this.OPPORTUNITY_SEARCH_RESULTS,{resultsData:opportunities_template,opportunityCreateLink:opportunity.create_template,opportunityForm:opportunity.form_template});
			return opportunities_template;
		},
		getOpportunityDetailsTemplate:function(opportunity_record){
		  // for each opp record
			var opportunity_template = "";
			var opportunity_list_item = "";
			// To link a opportunity with a ticket not needed for contracts and orders
			var opportunity_link_template = "<span class='hide opportunity_link pull-right'><a href='#' class='#{opportunity_status}' id='#{opportunity_id}'>#{opportunity_status}</a></span>";
			var link_status = (opportunity_record["link_status"] == undefined) ? "" : opportunity_record["link_status"];
			var unlink_status = (opportunity_record["unlink_status"] == undefined) ? "" : opportunity_record["unlink_status"];
			opportunity_link_template = (salesforceV2Bundle.agentSettings == "1") ? opportunity_link_template : "";
			if(link_status && unlink_status){
				if(opportunity_record["IsDeleted"]){ // Deleted flag will be shown for linked deleted opportunities
					opportunity_link_template += "<div class='opp-flag pull-right'>Deleted</div>";
				}
				else{
					opportunity_link_template += "<div class='opp-flag pull-right'>Linked</div>";
				}
				opportunity_list_item += opportunity_link_template.interpolate({opportunity_id:opportunity_record.Id,opportunity_status:"Unlink"});
			}
			else if(link_status === false){
				opportunity_list_item += opportunity_link_template.interpolate({opportunity_id:opportunity_record.Id,opportunity_status:"Link"});
			}
			opportunity_record["type"] = "Opportunity";
			opportunity_template += '<li><a class="multiple-opportunities salesforce-opportunity-tooltip" title="'+opportunity_record.Name+'" href="#">'+opportunity_record.Name+'</a>'+opportunity_list_item+'</li>';
			opportunity_template += this.resourceSectionTemplate(this.salesforceV2Bundle.opportunityFields.split(","),this.opportunityInfo,opportunity_record);
			return opportunity_template;
		},
		getEmptyOpportunitiesTemplate:function(eval_params,crmWidget){
			var opportunity = this.getOpportunityCreateTemplate(eval_params);
			var opportunities_template = _.template(this.OPPORTUNITY_SEARCH_RESULTS_NA,{opportunityCreateLink:opportunity.create_template,opportunityForm:opportunity.form_template});
			return opportunities_template;
		},
		getEmptyOrdersTemplate:function(eval_params,crmWidget){
			var orders_template = JST["app/integrations/salesforce_v2/object_search_results_na"]({object_name: "Orders", object_field: "orders"});
			return orders_template;
		},
		getEmptyContractsTemplate:function(eval_params,crmWidget){
			var contracts_template = JST["app/integrations/salesforce_v2/object_search_results_na"]({object_name: "Contracts", object_field: "contracts"});
			return contracts_template;
		},
		getOpportunityCreateTemplate:function(eval_params){
			var opportunity_create_template = "";
			var opportunity_form = "";
			var result = undefined;
			if(!salesforceV2Bundle.remote_integratable_id && salesforceV2Bundle.ticket_id){
				if(salesforceV2Bundle.agentSettings == "1"){
					opportunity_create_template += '<div class="opportunity_create pull-right"><span class="contact-search-result-type"><a id="create_new_opp_v2" href="#" rel="freshdialog" data-target="#create_sf_opportunity_v2_'+eval_params.Id+'" data-title="Create Opportunity" data-width="500" data-keyboard="false" data-template-footer="">Create New</a></span></div>';
					var stage_options = salesforceV2Bundle.opportunity_stage;
					var stage_dropdown_options = "";
					for(i=0;i<stage_options.length;i++){
						stage_dropdown_options += '<option id="'+i+'" value="'+stage_options[i][1]+'">'+stage_options[i][0]+'</option>';
					}
					opportunity_form += JST["app/integrations/salesforce_v2/opportunity_create_form"]({
						stage_options:stage_dropdown_options,
						account_id:eval_params.Id
					});
				}
			}
			result = {create_template:opportunity_create_template,form_template:opportunity_form};
			return result;
			},
		handleOpportunitesSection:function(eval_params,crmWidget,cloudobj){
			var _this = this;
			var opportunity_records = this.salesforceV2Bundle.opportunityHash[eval_params.Id];
			if($("#create_new_opp_v2").length){
				$(".salesforce_v2_contacts_widget_bg").on('click','#create_new_opp_v2',(function(ev){
					ev.preventDefault();
					_this.bindOpportunitySubmitEvents(eval_params,crmWidget,cloudobj);
				}));
			}
			if(opportunity_records && opportunity_records.length){
				_this.bindOpportunityEvents();
				_this.bindOpportunityLinkEvents(eval_params,crmWidget,cloudobj);
			}
		},
		handleContractsSection:function(eval_params,crmWidget){
			var _this = this;
			var contract_records = this.salesforceV2Bundle.contractHash[eval_params.Id];
			if(contract_records && contract_records.length){
				_this.bindContractEvents();
			}
		},
		handleOrdersSection:function(eval_params,crmWidget){
			var _this = this;
			var order_records = this.salesforceV2Bundle.orderHash[eval_params.Id];
			if(order_records && order_records.length){
                _this.bindOrderEvents();
			}
		},
		handleCRMResource:function(sf_resource,crmWidget, cloudobj){
			if(sf_resource.type == "Account"){ // This will handle opportunites if the opportunity_view is enabled
				if(!(salesforceV2Bundle.opportunityView == "1" || salesforceV2Bundle.contractView == "1" || salesforceV2Bundle.orderView == "1")){
					cloudobj.renderContactWidget(sf_resource,crmWidget);					
				}
				// Increment a counter Based on the number of request we are waiting.
				// Decrement the counter Inside the respective LoadObject: functions
				// If the Counter value is Zero Do the rendering. 
				this.account_related_calls_received = 0;
				if(salesforceV2Bundle.opportunityView == "1"){
					var opportunity_records = this.salesforceV2Bundle.opportunityHash[sf_resource.Id];        
					if(opportunity_records == undefined){
						this.account_related_calls_received++;
						this.getRelatedOpportunities(sf_resource,crmWidget,cloudobj);
					}
				}
				if(salesforceV2Bundle.contractView == "1"){
					var contract_records = this.salesforceV2Bundle.contractHash[sf_resource.Id];      
					if(contract_records == undefined){
						this.account_related_calls_received++;
						this.getRelatedContracts(sf_resource,crmWidget,cloudobj);
					}
				}
				if(salesforceV2Bundle.orderView == "1"){
					var order_records = this.salesforceV2Bundle.orderHash[sf_resource.Id];
					if(order_records == undefined){
						this.account_related_calls_received++;
						this.getRelatedOrders(sf_resource,crmWidget,cloudobj);
					}
				}
				if(this.account_related_calls_received == 0){
					cloudobj.renderContactWidget(sf_resource,crmWidget);					
				}
			}
			else{
				cloudobj.renderContactWidget(sf_resource,crmWidget);
			}
		},
		processFailure:function(eval_params,crmWidget,msg,cloudobj){
			cloudobj.renderContactWidget(eval_params,crmWidget);
			cloudobj.showError(msg);
		},
		resetSalesforceBundle:function(salesforceV2Bundle){
			var newSalesforceBundle = {};
			var bundleProperties = [
			                          "domain","ticket_id","reqCompany","reqEmails",
			                          "contactFields","opportunityFields","accountFields",
			                          "contactLabels","opportunityLabels","accountLabels",
			                          "leadLabels","leadFields","reqName","contractFields",
			                          "contractLabels","orderFields","orderLabels","ticket_company",
			                          "opportunityView","orderView","contractView"
			                       ]
			for(i=0;i<bundleProperties.length;i++){
				newSalesforceBundle[bundleProperties[i]] = salesforceV2Bundle[bundleProperties[i]];
			}
			return newSalesforceBundle;
		},
		bindContractEvents: function(){
			$(".multiple-contracts").click(function(ev){
				ev.preventDefault();
				var _this = $(this);
				if(_this.parent().next(".opportunity_details").css('display') != 'none'){
					_this.toggleClass('active');
					_this.parent().next(".opportunity_details").hide();
				}else{
					$(".opportunity_link").hide();
					$(".opp-flag").show();
					$(".salesforce-opportunity-tooltip").each(function(){
						var _self = $(this);
						if(_self !== _this){
							_self.removeClass('active');
						}
					});
					$(".opportunity_details").hide();
					_this.toggleClass("active");
					_this.parent().next(".opportunity_details").show();
				}
			});
		},
		bindOrderEvents: function(){
			$(".multiple-orders").click(function(ev){
				ev.preventDefault();
				var _this = $(this);
				if(_this.parent().next(".opportunity_details").css('display') != 'none'){
					_this.toggleClass('active');
					_this.parent().next(".opportunity_details").hide();
				}else{
					$(".opportunity_link").hide();
					$(".opp-flag").show();
					$(".salesforce-opportunity-tooltip").each(function(){
						var _self = $(this);
						if(_self !== _this){
							_self.removeClass('active');
						}
					});
					$(".opportunity_details").hide();
					_this.toggleClass("active");
					_this.parent().next(".opportunity_details").show();
				}
			});
		},
		bindOpportunityEvents: function(){
			$(".multiple-opportunities").click(function(ev){
				ev.preventDefault();
				var _this = $(this);
				if(_this.parent().next(".opportunity_details").css('display') != 'none'){
					$(".opportunity_link").hide();
					$(".opp-flag").show();
					_this.toggleClass('active');
					_this.parent().next(".opportunity_details").hide();
				}else{
					$(".opportunity_link").hide();
					_this.siblings(".opp-flag").hide();
					_this.next(".opportunity_link").show();
					$(".salesforce-opportunity-tooltip").each(function(){
						var _self = $(this);
						if(_self !== _this){
							_self.removeClass('active');
						}
					});
					$(".opportunity_details").hide();
					_this.toggleClass("active");
					_this.parent().next(".opportunity_details").show();
				}
			});
		},
		bindOpportunityLinkEvents:function(eval_params,crmWidget,cloudobj){
			var _this = this;
			$(".Link").off('click').on('click',function(ev){
				ev.preventDefault();
				var opportunity_id = $(this).attr('id');
				_this.linkOpportunity(opportunity_id,eval_params,crmWidget,cloudobj);
			});
			$(".Unlink").off('click').on('click',function(ev){
				ev.preventDefault();
				var opportunity_id = $(this).attr('id');
				_this.unlinkOpportunity(opportunity_id,eval_params,crmWidget,cloudobj);
			});
		},
		bindOpportunitySubmitEvents:function(eval_params,crmWidget,cloudobj){
			var _this = this;
			var account_id = eval_params.Id;
			this.clearOpportunityFormErrors();
			$("#opportunity-submit-v2-"+account_id).off('click').on('click',function(ev){
				ev.preventDefault();
				$(this).attr("disabled","disabled").val("Creating...");
				_this.createOpportunity(eval_params,crmWidget,cloudobj);
			});
			$("#opportunity-cancel-v2-"+account_id).off('click').on('click',function(ev){
				ev.preventDefault();
				$("#create_sf_opportunity_v2_"+account_id).modal("hide")
				_this.resetOpportunityForm(account_id);
			});
			$("#create_sf_opportunity_v2_"+account_id+" .close").on('click',function(ev){
				ev.preventDefault();
				_this.resetOpportunityForm(account_id);
			});
		},
		linkOpportunity:function(opportunity_id,eval_params,crmWidget,cloudobj){
			var _this = this;
			this.resetOpportunityDialog();
			this.showLoadingIcon("salesforce_v2_contacts_widget");
			freshdeskWidget.request({
				event:"link_opportunity", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:"salesforce_v2",
				payload: JSON.stringify({ ticket_id:salesforceV2Bundle.ticket_id, remote_id:opportunity_id }),
				on_success: function(response){
					response = response.responseJSON;
					_this.handleOpportunityLink(response,eval_params,crmWidget,opportunity_id,true,cloudobj);
				},
				on_failure: function(response){
					var message = response.responseJSON.message || response.responseJSON;
					_this.processFailure(eval_params,crmWidget,message,cloudobj);
			  } 
			});
		},
		unlinkOpportunity:function(opportunity_id,eval_params,crmWidget,cloudobj){
			var _this = this;
			this.showLoadingIcon("salesforce_v2_contacts_widget");
			freshdeskWidget.request({
				event:"unlink_opportunity", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:"salesforce_v2",
				payload: JSON.stringify({ ticket_id:salesforceV2Bundle.ticket_id, remote_id:opportunity_id }),
				on_success: function(response){
					response = response.responseJSON;
					_this.handleOpportunityLink(response,eval_params,crmWidget,opportunity_id,false,cloudobj);
				},
				on_failure: function(response){
					var message = response.responseJSON.message || response.responseJSON;
					_this.processFailure(eval_params,crmWidget,message,cloudobj);
				} 
			});
		},
		handleOpportunityLink:function(response,eval_params,crmWidget,opportunity_id,linkStatus,cloudobj){
			if(response.error){
				eval_params.error = response.error;
				salesforceV2Bundle.remote_integratable_id = response.remote_id;
				this.removeOtherAccountOpportunities(eval_params);
				this.account_related_calls_received = 1;
				this.getRelatedOpportunities(eval_params,crmWidget,cloudobj);
				if(salesforceV2Bundle.contractView == "1"){
					this.account_related_calls_received++;
					this.getRelatedContracts(eval_params,crmWidget,cloudobj); 
				}
				if(salesforceV2Bundle.orderView == "1"){
					this.account_related_calls_received++;
					this.getRelatedOrders(eval_params,crmWidget,cloudobj);
				}
			}
			else{
				salesforceV2Bundle.remote_integratable_id = linkStatus ? opportunity_id : "";
				this.resetOtherAccountOpportunities(eval_params,linkStatus);
				this.account_related_calls_received = 1;
				this.getRelatedOpportunities(eval_params,crmWidget,cloudobj,linkStatus);
				if(salesforceV2Bundle.contractView == "1"){
					this.account_related_calls_received++;
					this.getRelatedContracts(eval_params,crmWidget,cloudobj);
				}
				if(salesforceV2Bundle.orderView == "1"){
					this.account_related_calls_received++;        
					this.getRelatedOrders(eval_params,crmWidget,cloudobj);
				}
			}
		},
		createOpportunity:function(eval_params,crmWidget,cloudobj){
			var obj = this;
			if(salesforceV2Widget.validateInput()){
				$("#salesforce-opportunity-validation-errors-v2").hide();
				var date = new Date($("#opportunity_close_date_v2").val()).toString("yyyy-MM-dd");
				var stage_name = $("#opportunity_stage_v2").val();
				var name = $("#opportunity_name_v2").val();
				var amount = $("#opportunity_amount_v2").val();
				var opportunity_params = { ticket_id:salesforceV2Bundle.ticket_id, AccountId:eval_params.Id,Name:name, CloseDate:date, StageName:stage_name, Amount:amount,type:"opportunity"};
				freshdeskWidget.request({
					event:"create_opportunity", 
					source_url:"/integrations/sync/crm/fetch",
					app_name:"salesforce_v2",
					payload: JSON.stringify(opportunity_params),
					on_success:function(response){
						response = response.responseJSON;
						obj.processOpportunityPostCreate(response,eval_params,crmWidget,cloudobj);
					},
					on_failure:function(response){
						var message = response.responseJSON.message || response.responseJSON;
						$("#opportunity-submit-v2-"+eval_params.Id).removeAttr('disabled').val("Create");
						$(".salesforce-opportunity-custom-errors-v2").show().html("<span>Opportunity creation failed."+" "+message+"</span>");
					} 
				});
			}
			else{
			  $(".salesforce-opportunity-custom-errors-v2").hide();
			  $("#opportunity-submit-v2-"+eval_params.Id).removeAttr('disabled').val("Create");
			}
		},
		processOpportunityPostCreate:function(response,eval_params,crmWidget,cloudobj){
			$("#create_sf_opportunity_v2_"+eval_params.Id).modal("hide");
			this.resetOpportunityForm(eval_params.Id);
			if(response.error){
				eval_params.error = response.error;
				salesforceV2Bundle.remote_integratable_id = response.remote_id;
				this.removeOtherAccountOpportunities(eval_params);
				this.resetOpportunityDialog();
				this.account_related_calls_received = 1;
				this.getRelatedOpportunities(eval_params,crmWidget,cloudobj);
				if(salesforceV2Bundle.contractView == "1"){
					this.account_related_calls_received++;
					this.getRelatedContracts(eval_params,crmWidget,cloudobj);
				}
				if(salesforceV2Bundle.orderView == "1"){
					this.account_related_calls_received++;
					this.getRelatedOrders(eval_params,crmWidget,cloudobj);
				}
			}
			else{
				this.linkOpportunity(response.Id,eval_params,crmWidget,cloudobj);
			}
		},
		validateInput:function(){
			var datecheck = new Date($("#opportunity_close_date_v2").val().trim());
			$(".salesforce-opportunity-custom-errors-v2").hide();
			if(!$("#opportunity_name_v2").val().trim()){
				this.showValidationErrors("Please enter a name");
				return false;
			}
			if(!$("#opportunity_stage_v2").val().trim()){
				this.showValidationErrors("Please select an opportunity stage");
				return false;
			}
			if(!$("#opportunity_close_date_v2").val().trim() || datecheck.toString() == "Invalid Date"){
				this.showValidationErrors("Enter value for close date");
				return false;
			}
			var opp_amount = $("#opportunity_amount_v2");
			if(opp_amount.val().trim() && isNaN(opp_amount.val())){
				this.showValidationErrors("Please enter valid amount");
				return false;
			}
			return true;
		},
		showValidationErrors:function(msg){
			var sf_val_error = $("#salesforce-opportunity-validation-errors-v2");
			sf_val_error.text(msg);
			sf_val_error.show();
		},
		resetOtherAccountOpportunities:function(eval_params,link_status){
			var records = undefined;
			for(key in this.salesforceV2Bundle.opportunityHash){
				records = this.salesforceV2Bundle.opportunityHash[key];
				if (key != eval_params.Id && records.length){
					for(i=0;i<records.length;i++){
						records[i]["link_status"] = link_status;
					}
					this.salesforceV2Bundle.opportunityHash[key] = records;
				}
			}
		},
		removeOtherAccountOpportunities:function(eval_params){
			for(key in this.salesforceV2Bundle.opportunityHash){
				if (key != eval_params.Id){
					this.salesforceV2Bundle.opportunityHash[key] = undefined;
				}
			}
		},
		resetOpportunityForm:function(account_id){
			this.clearOpportunityFormErrors();
			$("#opportunity-submit-v2-"+account_id).removeAttr('disabled').val("Create");
			$("#opportunity_stage_v2").select2("val",salesforceV2Bundle.opportunity_stage[0][1]);
			$("#salesforce-opportunity-form-v2")[0].reset();
		},
		clearOpportunityFormErrors:function(){
			$("#salesforce-opportunity-validation-errors-v2").hide();
			$(".salesforce-opportunity-custom-errors-v2").hide();
		},
		resetOpportunityDialog:function(){
			if($("#create_new_opp_v2").data("freshdialog")){
				$("#"+ $("#create_new_opp_v2").data("freshdialog").$dialogid).remove();
			}
		},
		showLoadingIcon:function(widget_name){
			$("#"+widget_name+" .content").html("");
			$("#"+widget_name).addClass('sloading loading-small');
		},
		initOpportunityContractOrderHash:function(){
			this.salesforceV2Bundle.opportunityHash = {};
			this.salesforceV2Bundle.contractHash = {};
			this.salesforceV2Bundle.orderHash = {};
		},
		OPPORTUNITY_SEARCH_RESULTS:
			'<div class="bottom_div mt10 mb10"></div>'+
			'<div class="title salesforce_v2_contacts_widget_bg">' +
			  '<div id="opportunities"><b>Opportunities</b></div>'+
			  '<%=opportunityCreateLink%>'+
			  '<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
			  '<%=opportunityForm%>'+
			'</div>',
		OPPORTUNITY_SEARCH_RESULTS_NA:
			'<div class="bottom_div mt10 mb10"></div>'+
			'<div class="title contact-na salesforce_v2_contacts_widget_bg">' +
			  '<div id="opportunities"><b>Opportunities</b></div>'+
			  '<%=opportunityCreateLink%>'+
			  '<div class="name"  id="contact-na">No opportunities found for this account</div>'+
			  '<%=opportunityForm%>'+
			'</div>',
		OPPORTUNITY_TEMPLATE: 
    		'<div class="salesforce-widget">' +
    			'<div class="clearfix">' +
    			  '<span class="ellipsis"><span class="tooltip" title="<%=label%>"><%=label%>:</span></span>' +
    				'<label id="contact-<%=field%>"><a target="_blank" href="<%=opp_external_link%>"><%=value%></a></label>' +
    			'</div>' +
    		'</div>',
		COMMON_CONTACT_TEMPLATE:
			'<div class="salesforce-widget">' +
    	    	'<div class="clearfix">' +
    	    	  '<span class="ellipsis"><span class="tooltip" title="<%=label%>"><%=label%>:</span></span>' +
    		    	'<label class="para-less" id="contact-<%=field%>"><%=value%></label>' +
    		    	'<span class="toggle-para q-para-span hide"><p class="q-marker-more"></p></span>'+
    	    	'</div>'+
	    '</div>'
		}
	}(window.jQuery));

	//update widgets inner join applications on applications.id = widgets.application_id set script=replace(script, " token:", "oauth_token:") where applications.name="salesforce";

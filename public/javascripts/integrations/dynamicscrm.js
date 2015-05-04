var DynamicsWidget = Class.create();
DynamicsWidget.prototype= {

	CONTACT_SEARCH_RESULTS:
		'<div class="title salesforce_widget_bg">' +
			'<div id="number-returned"><b> <%=resLength%> results for <%=requester%> </b></div>'+
			'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
		'</div>',

	VIEW_CONTACT:
		'<div class="title salesforce_widget_bg">' +
			'<div class="row-fluid">' +
				'<div id="contact-name" class="span8">'+
				'<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
				'<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title"><%=Name%></a></div>' +
				'<div class="span4"><span class="contact-search-result-type pull-right"><%=(type || "")%></span></div>'+
			'</div>' + 
		'</div>',

	CONTACT_NA:
		'<div class="title contact-na <%=widget_name%>_bg">' +
			'<div class="name"  id="contact-na">Cannot find <%=reqName%> in <%=app_name%>.</div>'+
		'</div>',

	CONTACT_LINK:
		'<%=domain_name%>'+'/main.aspx?etn='+'<%=entity_type%>'+'&pagetype=entityrecord&id=%7B'+'<%=contact_id%>'+'%7D',

	initialize:function(dynamicsBundle){
		jQuery("#dynamicscrm_widget").addClass('loading-fb');
		dynamicsWidget = this;
		this.dynamicsBundle = dynamicsBundle;
		this.crmData = null;
		this.contact_type_map = { "contact" : "Contact", "lead" : "Lead", "account" : "Account"};
		this.ignore_labels = ["internal_use_entity_type", "Full Name", "Contact ID", "Account ID", "Account Name"];
		var init_reqs = [];
		init_reqs = [{
				source_url: "/integrations/dynamics_crm/widget_data",
				content_type: "application/json",
				method: "get",
				email: dynamicsBundle.reqEmail,
				on_success: dynamicsWidget.initsuccess.bind(this),
				on_failure: dynamicsWidget.initfailure.bind(this)
		}];
		if(dynamicsBundle.reqEmail ) {
			this.freshdeskWidget = new Freshdesk.Widget({
				/* TODO : check if the below values needed to come via bundle and what is the usage of these values */
				app_name:"Dynamics CRM",
				widget_name:"dynamicscrm_widget",
				application_id: 25,
				integratable_type:"crm",
				init_requests: init_reqs
			});
		}
	},

	initsuccess:function(evt){
		response_json = evt.responseJSON
		dynamicsWidget.crmData = response_json;
		dynamicsWidget.renderCrmResults(response_json);
	},

	initfailure:function(evt){
		dynamicsWidget.processFailure();
	},

	renderCrmResults: function(){
		var crm_data = dynamicsWidget.crmData;
		var dyn_crm_results = "";

		for(var i = 0; i < crm_data.length; i++) {
			var name = crm_data[i]["Full Name"] || crm_data[i]["Account Name"];
			dyn_crm_results += '<li><a class="multiple-contacts" href="javascript:dynamicsWidget.contactChanged(' + i + ')" data-contact="' + i + '">'+ escapeHtml(name) +'</a><span class="contact-search-result-type pull-right">'+dynamicsWidget.contact_type_map[crm_data[i]["internal_use_entity_type"]]+'</span></li>';
		}
		var results_number = {resLength: crm_data.length, requester: dynamicsWidget.dynamicsBundle.reqEmail, resultsData: dyn_crm_results};
		if(crm_data.length > 0) {
			dynamicsWidget.renderSearchResultsWidget(results_number);
		} else {
			dynamicsWidget.renderContactNa();
		}
	},

	contactChanged:function(value){
		if(value == -1){
			jQuery('#dynamics-contact-widget').hide();
		}else{
			var entity_type = dynamicsWidget.crmData[value]["internal_use_entity_type"];
			var contact_id = dynamicsWidget.crmData[value]["Contact ID"];
			var domain_name = dynamicsWidget.dynamicsBundle.endpoint.toLowerCase().split("/xrmservices")[0];
			var link_params = { domain_name : domain_name, entity_type : entity_type, contact_id : contact_id };
			var contact_link = ( function(){ return _.template(dynamicsWidget.CONTACT_LINK, link_params)} ) ();
			var name = dynamicsWidget.crmData[value]["Full Name"] || dynamicsWidget.crmData[value]["Account Name"];
			var eval_params = { count : dynamicsWidget.crmData.length, type : dynamicsWidget.contact_type_map[entity_type], Name : escapeHtml(name), url : contact_link };
			dynamicsWidget.renderContactWidget(eval_params, value);
		}
	},

	renderContactNa:function(){
		var eval_params = { widget_name: "salesforce_widget", reqName : dynamicsWidget.dynamicsBundle.reqEmail, app_name : "DynamicsCRM" };
		dynamicsWidget.freshdeskWidget.options.application_html = function(){ return _.template(dynamicsWidget.CONTACT_NA, eval_params);} 
		dynamicsWidget.freshdeskWidget.display();
		jQuery("#dynamicscrm_widget").removeClass('loading-fb');
	},

	renderContactWidget:function(eval_params, entity_index){
		var contact_fields_template = dynamicsWidget.getTemplate(entity_index); // Field and label html is populated here.
		dynamicsWidget.freshdeskWidget.options.application_html = function(){ return _.template(dynamicsWidget.VIEW_CONTACT, eval_params)+""+contact_fields_template;	} // in contact_fields_template custom field is populated
		dynamicsWidget.freshdeskWidget.display();
		jQuery("#dynamicscrm_widget").on('click','#search-back', (function(ev){
			ev.preventDefault();
			dynamicsWidget.renderCrmResults();
		}));
	},

	renderSearchResultsWidget:function(results_number){
		dynamicsWidget.freshdeskWidget.options.application_html = function(){ return _.template(dynamicsWidget.CONTACT_SEARCH_RESULTS, results_number);}
		dynamicsWidget.freshdeskWidget.display();
		jQuery("#dynamicscrm_widget").removeClass('loading-fb');
	},

	parse_nested_custom_field:function(field_json){
		field_data = ((typeof(field_json['Name']) != "undefined")) ? escapeHtml(field_json['Name']) : "Not a valid data type.";
		return field_data;
	},

	getTemplate:function(entity_index){
		var contactTemplate ="";
		entity_meta_data = dynamicsWidget.crmData[entity_index];
		var count = 0;
		for (var label in entity_meta_data) {
			if ((label == "internal_use_entity_type") || (entity_meta_data[label] == null) ) { continue; }
			var field = (typeof(entity_meta_data[label]) == "object") ? this.parse_nested_custom_field(entity_meta_data[label]) : entity_meta_data[label];
			if (count==5) {
				contactTemplate+='<span class="hide" id="'+ entity_meta_data['internal_use_entity_type']+'_all_data">';
	 		}
			if (jQuery.inArray(label, dynamicsWidget.ignore_labels) != -1) {
				continue;
			}
			if(field ==null || field  == undefined) {
				field  ="N/A";
			}
 			contactTemplate+= '<div class="salesforce-widget">' +
				'<div class="clearfix">' +
					'<span class="ellipsis tooltip" data-original-title="'+escapeHtml(label)+'">'+ escapeHtml(label) +':</span>' +
				'	<label id="contact-'+escapeHtml(label)+'" class="ellipsis tooltip" title="'+ escapeHtml(field) +'">'+ escapeHtml(field) +'</label>' +
				'</div></div>';
			count++;
		}
		if (count>5) {
			contactTemplate+='<div id="less_'+ entity_meta_data['internal_use_entity_type']+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#more_'+ entity_meta_data['internal_use_entity_type']+'_button\').show();jQuery(\'#'+ entity_meta_data['internal_use_entity_type']+'_all_data\').addClass(\'hide\');return false;">less</a></div>';
			contactTemplate+= '</span><div id="more_'+ entity_meta_data['internal_use_entity_type']+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#less_'+ entity_meta_data['internal_use_entity_type']+'_button\').show();jQuery(\'#'+ entity_meta_data['internal_use_entity_type']+'_all_data\').removeClass(\'hide\');return false;" >more</a></div>';
		}
		return contactTemplate;
	},

	processFailure:function(evt){
		this.freshdeskWidget.alert_failure("Unable to establish connection with DynamicsCRM. Please contact Support at support@freshdesk.com")
	}
}

dynamicsWidget = new DynamicsWidget(dynamicscrmBundle);


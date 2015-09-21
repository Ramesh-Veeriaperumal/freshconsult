var SugarWidget = Class.create();
SugarWidget.prototype= {

	SUGAR_CONTACT:new Template(
			'<span class="contact-type hide"></span>' +
			'<div class="title">' +				
				'<div class="name">' +
					'<div id="contact-name"></div>' +
				    '<div id="contact-desig"></div>'+
			    '</div>' + 
		    '</div>' + 
		    '<div class="field half_width">' +
		    	'<div id="crm-contact">' +
				    '<label>Contact</label>' +
				    '<span id="contact-address"></span>' +
			    '</div>'+	
		    	'<div  id="crm-dept">' +
				    '<label>Department</label>' +
				    '<span id="contact-dept"></span>' +
			    '</div>'+	
		    '</div>'+
		    '<div class="field half_width">' +
		    	'<div  id="crm-phone">' +
				    '<label>Phone</label>' +
				    '<span id="contact-phone"></span>'+
			    '</div>' +
				'<div id="crm-mobile">' +
				    '<label>Mobile</label>' +
				    '<span id="contact-mobile"></span>'+
				'</div>' +
			'</div>'+
			'<div class="external_link"><a id="search-back" href="javascript:sugarWidget.renderSearchResults();"> &laquo; Back </a><a target="_blank" id="crm-view">View <span id="crm-contact-type"></span> in SugarCRM</a></div>'),

	SUGAR_CONTACT_NA:new Template(
		'<div class="title contact-na">' +
			'<div class="name"  id="contact-na"></div>'+
		'</div>'),

	SUGAR_SEARCH_RESULTS:new Template(
		'<div class="title">' +
			'<div id="number-returned" class="name"></div>'+
			'<div id="search-results"></div>'+
		'</div>'),

	
	initialize:function(sugarBundle){
		jQuery("#sugarcrm_contacts_widget").addClass('loading-fb');
		sugarWidget = this;
		this.sugarBundle = sugarBundle;
		this.failureCount = 0;
		var init_reqs = [];
		if(sugarBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				app_name:"Sugar CRM",
				widget_name:"sugarcrm_contacts_widget",
				application_id:sugarBundle.application_id,
				integratable_type:"crm",
				domain:sugarBundle.domain,
				ssl_enabled:sugarBundle.ssl_enabled || "false"
			});
			var sugar_session = Cookie.retrieve("sugar_session");
			if(sugar_session == "" || sugar_session == null){
				sugarWidget.get_sugar_session();
			}
			else{
				sugarWidget.get_sugar_contact();
			}
		
		}
		//if(loadInline) this.convertToInlineWidget();
	},

	handleContactSuccess:function(resData){
		resJ = sugarWidget.get_json(resData);
		sugarWidget.response = resJ;
		//Handle Session Timeout
		if (resJ.number != undefined && (resJ.number == 11)){
			sugarWidget.failureCount += 1;
			if (sugarWidget.failureCount <=5 ){
				sugarWidget.get_sugar_session();
			}
			else{
				sugarWidget.processFailure();
				jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
				return;
			}
		}
		//sugarWidget.renderContactWidget();
		if (resJ.result_count > 0) {
			//renderContact
			if(resJ.result_count == 1){
				entry_list = resJ.entry_list[0];
				sugarWidget.renderContact(entry_list);
			}
			else if(resJ.result_count > 1){
				sugarWidget.renderSearchResults();
				jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');

			}

		} else{
			if(resJ.result_count != undefined){
			sugarWidget.searchLeads();
			//sugarWidget.renderContactNa();
			//jQuery('#contact-na').text('Cannot find requester in SugarCRM');
			}	
		} 
	},

	handleLeadSuccess:function(resData){
		resJ = sugarWidget.get_json(resData);
		if(resJ.result_count > 0){
			sugarWidget.lead = true;
			sugarWidget.handleContactSuccess(resData);	
		}
		else{
			sugarWidget.renderContactNa();
			jQuery('#contact-na').text('Cannot find requester in SugarCRM');
		}
		
	},

	searchLeads:function(){
		var entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"#{session}","module_name":"Leads","query":"#{email_query}","order_by":"", "offset":0,"select_fields":[],"link_name_to_fields_array":[],"max_results":"","deleted":0}';
		sugarWidget.freshdeskWidget.request({
			rest_url: "service/v4/rest.php",
			method:"post",	
			body:entry_list_body.interpolate({session: Cookie.retrieve("sugar_session")||"", email_query: "leads.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address ='"+ sugarWidget.sugarBundle.reqEmail +"')"}),
			content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
			on_failure: sugarWidget.processFailure,
			on_success: sugarWidget.handleLeadSuccess.bind(this)
		});
	},

	renderSearchResults:function(){
		var sugarResults="";
		sugarWidget.renderSearchResultsWidget();
		for(var i=0; i<sugarWidget.response.result_count; i++){
			var name = escapeHtml(resJ.entry_list[i].name_value_list.name.value);
			sugarResults += '<a href="javascript:sugarWidget.contactChanged(' + i + ')">'+ name +'</a><br/>';
		}
		jQuery('#number-returned').text(sugarWidget.response.result_count + " results returned for " + sugarWidget.sugarBundle.reqEmail)
		jQuery('#search-results').html(sugarResults);
	},

	renderContact:function(entry_list){
		this.entry_list = entry_list;
		sugarWidget.get_sugar_version();
	},

	contactChanged:function(value){
		if(value == -1){
			jQuery('#sugar-contact-widget').hide();
			jQuery('#crm-contact').hide();
			jQuery('#crm-phone').hide();
			jQuery('#crm-mobile').hide();
			jQuery('#crm-dept').hide();
		}else{
			entry_list = sugarWidget.response.entry_list[value];
			sugarWidget.renderContact(entry_list);
		}
		
	},

	renderContactNa:function(){
		sugarWidget.freshdeskWidget.options.application_html = function(){ return sugarWidget.SUGAR_CONTACT_NA.evaluate({});	} 
		sugarWidget.freshdeskWidget.display();
		jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');		
	},

	renderContactWidget:function(){
		sugarWidget.freshdeskWidget.options.application_html = function(){ return sugarWidget.SUGAR_CONTACT.evaluate({});	} 
		sugarWidget.freshdeskWidget.display();
	},

	renderSearchResultsWidget:function(){
		sugarWidget.freshdeskWidget.options.application_html = function(){ return sugarWidget.SUGAR_SEARCH_RESULTS.evaluate({});	} 
		sugarWidget.freshdeskWidget.display();
	},

	get_formatted_address:function(contactJson){
		street1 =  (contactJson.primary_address_street.value == "") ? "" : (contactJson.primary_address_street.value+", ")
		street2 =  (contactJson.primary_address_street_2.value == "") ? "" : (contactJson.primary_address_street_2.value+", ")
		street3 =  (contactJson.primary_address_street_3.value == "") ? "" : (contactJson.primary_address_street_3.value+", ")
		state = (contactJson.primary_address_state.value == "") ? "" : (contactJson.primary_address_state.value+", ")
		city = (contactJson.primary_address_city.value == "") ? "" : (contactJson.primary_address_city.value+", ")
		country = (contactJson.primary_address_country.value == "") ? "" : (contactJson.primary_address_country.value)
		address = street1+street2+street3+city+state+country
		addressLine1 = street1+street2+street3
		city = state+city
		addressLine2 = (addressLine1=="") ? "" : (addressLine1 + "<br/>");
		addressLine2 = addressLine2 + ((city=="") ? "" : city);
		addressLine = (addressLine2=="") ? "" : (addressLine2 + "<br/>");
		addressLine = addressLine + ((country=="") ? "" : country)
		return addressLine
	},

	get_sugar_session:function(callBack){
		var session_body = 'method=login&input_type=JSON&response_type=JSON&rest_data={"user_auth" : {"user_name" : "#{username}", "password" : "#{password}", "version" : 4},"application": "freshdesk_sugarcrm"}';
		sugarWidget.freshdeskWidget.request({
				rest_url: "service/v4/rest.php",
				method:"post",
				body:session_body.interpolate({username: sugarWidget.sugarBundle.username, password: sugarWidget.sugarBundle.password}),
				content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
				on_failure: sugarWidget.processFailure,
				on_success: this.handleSessionSuccess.bind(this)
			});
	},

	handleSessionSuccess:function(evt){
		responseText = evt.responseText;
		responseText = sugarWidget.removeRequestKeyword(responseText);
		resJ = jQuery.parseJSON(responseText);
		if (resJ.number != undefined && (resJ.number == 10)){
			this.freshdeskWidget.alert_failure("Please verify your Sugar credentials and try again.")
			jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
		}
		else{
			Cookie.update("sugar_session", resJ.id);
			sugarWidget.get_sugar_contact();			
		}
	},

	get_sugar_contact:function(){
		var entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"#{session}","module_name":"Contacts","query":"#{email_query}","order_by":"", "offset":0,"select_fields":[],"link_name_to_fields_array":[],"max_results":"","deleted":0}';
		sugarWidget.freshdeskWidget.request({
			rest_url: "service/v4/rest.php",
			method:"post",	
			body:entry_list_body.interpolate({session: Cookie.retrieve("sugar_session")||"", email_query: "contacts.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address ='"+ sugarWidget.sugarBundle.reqEmail +"')"}),
			content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
			on_failure: sugarWidget.processFailure,
			on_success: sugarWidget.handleContactSuccess.bind(this)
		});
	},

	get_sugar_version:function(){
		var entry_list_body = 'method=get_server_info&input_type=JSON&response_type=JSON&rest_data={"session":"#{session}","module_name":"Administrator","order_by":"", "offset":0,"select_fields":[],"link_name_to_fields_array":[],"max_results":"","deleted":0}',
			$obj = this;
		sugarWidget.freshdeskWidget.request({
			rest_url: "service/v4/rest.php",
			method:"post",	
			body:entry_list_body.interpolate({session: Cookie.retrieve("sugar_session")||""}),
			content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
			on_failure: sugarWidget.processVersionFailure,
			on_success: sugarWidget.handleVersionSuccess.bind(this)
		});
	},

	handleVersionSuccess:function(evt){
		responseText = evt.responseText;
		responseText = sugarWidget.removeRequestKeyword(responseText);
		resJ = jQuery.parseJSON(responseText);
		if (resJ.version == undefined){
			this.freshdeskWidget.alert_failure("Sugar CRM version couldn't be determined. Please try after sometime or contact support.")
			jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');
		}
		else{
			var version = resJ.version;
			var version_arr = version.split(".");
			var sugar_version = parseInt(version_arr[0]);

			sugarWidget.renderContactWidget();
			// Hide the search-back and multiple-contacts from the template since it is not relevant with single contact.
			jQuery('#multiple-contacts').hide();
			jQuery('#search-back').hide();
			contactJson = this.entry_list.name_value_list;
			title = escapeHtml(contactJson.title.value);
			account = (contactJson.account_name == undefined) ? "" : escapeHtml(contactJson.account_name.value);
			if(account != ""){
				account_link = sugarWidget.get_sugar_link("Accounts", sugar_version, contactJson.account_id.value);
				account = "<a target='_blank' href='" + account_link +"'>" + account +"</a>"	
			}
			
			desig = (title != "" && account != "" ) ? (title + ", " + account) : (title + account)
			address = escapeHtml(sugarWidget.get_formatted_address(contactJson));
			phone = escapeHtml(contactJson.phone_work.value);
			mobile = escapeHtml(contactJson.phone_mobile.value);
			department = escapeHtml(contactJson.department.value);
			if(sugarWidget.lead == true){
				contactLink = sugarWidget.get_sugar_link("Leads", sugar_version, this.entry_list.id);
				jQuery('#crm-contact-type').text("Lead");
				jQuery('#sugarcrm_contacts_widget .contact-type').text("Lead").show();
			}
			else{
				contactLink = sugarWidget.get_sugar_link("Contacts", sugar_version, this.entry_list.id);
				jQuery('#crm-contact-type').text("Contact");
				jQuery('#sugarcrm_contacts_widget .contact-type').text("Contact").show();
			}
			fullName = "<a target='_blank' href='" + contactLink  +"'>"+ escapeHtml(contactJson.name.value)+"</a>";
			address = (address != "") ? address : "N/A" ;
			phone = (phone != "") ? phone : "N/A" ;
			mobile = (mobile != "") ? mobile : "N/A" ;
			department = (department != "") ? department : "N/A" ;
			jQuery('#sugar-contact-widget').show();
			jQuery('#contact-name').html(fullName);
			jQuery('#contact-desig').html(desig);
			jQuery('#contact-address').html(address);
			jQuery('#contact-phone').text(phone)
			jQuery('#contact-mobile').text(mobile);
			jQuery('#contact-dept').text(department);

			jQuery('#crm-view').attr("href",contactLink);
			jQuery("#sugarcrm_contacts_widget").removeClass('loading-fb');

		}
	},

	processVersionFailure:function(evt){
				this.freshdeskWidget.alert_failure("Unable to establish connection with SugarCRM and determine the version. Please contact Support at support@freshdesk.com")
	},

	removeRequestKeyword:function(responseText){
		return responseText.replace(/request{/g,"{");	
	},

	get_sugar_link:function(module_name, sugar_version, id){
		var	link = "";
		if(sugar_version < 7) {
			link = sugarWidget.sugarBundle.domain + "/" + "index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3D"+module_name+"%26action%3DDetailView%26record%3D"+id; 
		} else {
			link = sugarWidget.sugarBundle.domain + "/#" + module_name + "/" + id;
		}
		return link;
	},

	get_json:function(resData){
		responseText = resData.responseText
		responseText = sugarWidget.removeRequestKeyword(responseText);
		return jQuery.parseJSON(responseText);
	},

	processFailure:function(evt){
		this.freshdeskWidget.alert_failure("Unable to establish connection with SugarCRM. Please contact Support at support@freshdesk.com")
	}


}
sugarWidget = new SugarWidget(sugarcrmBundle);


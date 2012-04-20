var SugarWidget = Class.create();
SugarWidget.prototype= {

	SUGAR_CONTACT:new Template(
			'<span class="contact-type hide"></span>' +
			'<div class="title">' +				
				'<div class="name">' +
					'<span id="contact-name"></span><br />' +
				    '<span id="contact-desig"></span>'+
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
		'<div class="title">' +
			'<div class="name"  id="contact-na"></div>'+
		'</div>'),

	SUGAR_SEARCH_RESULTS:new Template(
		'<div class="title">' +
			'<div id="number-returned" class="name"></div>'+
			'<div id="search-results"></div>'+
		'</div>'),

	
	initialize:function(sugarBundle){
		jQuery("#sugarcrm_widget").addClass('loading-fb');
		sugarWidget = this;
		this.sugarBundle = sugarBundle;
		this.failureCount = 0;
		var init_reqs = [];
		if(sugarBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				application_id:sugarBundle.application_id,
				integratable_type:"crm",
				anchor:"sugarcrm_widget",
				app_name:"sugarcrm",
				domain:sugarBundle.domain,
				ssl_enabled:sugarBundle.ssl_enabled || "false",
				login_content: null,
				application_content: null,
				application_resources:null
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
				jQuery("#sugarcrm_widget").removeClass('loading-fb');
				return;
			}
		}
		//sugarWidget.renderContactWidget();
		if (resJ.result_count > 0) {
			//renderContact
			if(resJ.result_count == 1){
				entry_list = resJ.entry_list[0];
				sugarWidget.renderContact(entry_list);
				jQuery('#multiple-contacts').hide();
				jQuery('#search-back').hide();
			}
			else if(resJ.result_count > 1){
				sugarWidget.renderSearchResults();
				jQuery("#sugarcrm_widget").removeClass('loading-fb');

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
		init_reqs = [{
			resource: "service/v4/rest.php",
			method:"post",	
			body:entry_list_body.interpolate({session: Cookie.retrieve("sugar_session")||"", email_query: "leads.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address ='"+ sugarWidget.sugarBundle.reqEmail +"')"}),
			content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
			on_failure: sugarWidget.processFailure,
			on_success: sugarWidget.handleLeadSuccess.bind(this)
		}];
		sugarWidget.freshdeskWidget.options.application_content = null; 
		sugarWidget.freshdeskWidget.options.application_resources = init_reqs;
		sugarWidget.freshdeskWidget.display();
	},

	renderSearchResults:function(){
		var sugarResults="";
		sugarWidget.renderSearchResultsWidget();
		for(var i=0; i<sugarWidget.response.result_count; i++){
			sugarResults += '<a href="javascript:sugarWidget.contactChanged(' + i + ')">'+resJ.entry_list[i].name_value_list.name.value+'</a><br/>';
		}
		jQuery('#number-returned').text(sugarWidget.response.result_count + " results returned for " + sugarWidget.sugarBundle.reqEmail)
		jQuery('#search-results').html(sugarResults);
	},

	renderContact:function(entry_list){

		sugarWidget.renderContactWidget();
		contactJson = entry_list.name_value_list;
		title = contactJson.title.value;
		account = (contactJson.account_name == undefined) ? "" : contactJson.account_name.value;
		if(account != ""){
			account_link = sugarWidget.sugarBundle.domain + "/" + "index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3DAccounts%26action%3DDetailView%26record%3D"+contactJson.account_id.value; 
			account = "<a target='_blank' href='" + account_link +"'>" + account +"</a>"	
		}
		
		desig = (title != "" && account != "" ) ? (title + ", " + account) : (title + account)
		address = sugarWidget.get_formatted_address(contactJson);
		phone = contactJson.phone_work.value;
		mobile = contactJson.phone_mobile.value;
		department = contactJson.department.value;
		if(sugarWidget.lead == true){
			contactLink = sugarWidget.sugarBundle.domain + "/" + "index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3DLeads%26action%3DDetailView%26record%3D"+entry_list.id
			jQuery('#crm-contact-type').text("Lead");
			jQuery('#sugarcrm_widget .contact-type').text("Lead").show();
		}
		else{
			contactLink = sugarWidget.sugarBundle.domain + "/" + "index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3DContacts%26action%3DDetailView%26record%3D"+entry_list.id
			jQuery('#crm-contact-type').text("Contact");
			jQuery('#sugarcrm_widget .contact-type').text("Contact").show();
		}
		fullName = "<a target='_blank' href='" + contactLink  +"'>"+contactJson.name.value+"</a>";
		jQuery('#sugar-contact-widget').show();
		jQuery('#contact-name').html(fullName);
		jQuery('#contact-desig').html(desig);
		(address != "") ? (jQuery('#contact-address').html(address).show()) : (jQuery('#crm-contact').addClass('hide')) ;
		(phone != "") ? jQuery('#contact-phone').text(phone) : (jQuery('#crm-phone').addClass('hide')) ;
		(mobile != "") ? jQuery('#contact-mobile').text(mobile) : (jQuery('#crm-mobile').addClass('hide')) ;
		(department != "") ? jQuery('#contact-dept').text(department) : (jQuery('#crm-dept').addClass('hide')) ;

		// If there is nothing to show in the left side, hide that too.
		if (jQuery('#crm-contact').hasClass('hide') && jQuery('#crm-dept').hasClass('hide')) {
			jQuery('#crm-contact').parent().addClass('hide');
		}
		jQuery('#crm-view').attr("href",contactLink);
		jQuery("#sugarcrm_widget").removeClass('loading-fb');
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
		sugarWidget.freshdeskWidget.options.application_content = function(){ return sugarWidget.SUGAR_CONTACT_NA.evaluate({});	} 
		sugarWidget.freshdeskWidget.options.application_resources = null;
		sugarWidget.freshdeskWidget.display();
		jQuery("#sugarcrm_widget").removeClass('loading-fb');
		
	},

	renderContactWidget:function(){
		sugarWidget.freshdeskWidget.options.application_content = function(){ return sugarWidget.SUGAR_CONTACT.evaluate({});	} 
		sugarWidget.freshdeskWidget.options.application_resources = null;
		sugarWidget.freshdeskWidget.display();
	},

	renderSearchResultsWidget:function(){
		sugarWidget.freshdeskWidget.options.application_content = function(){ return sugarWidget.SUGAR_SEARCH_RESULTS.evaluate({});	} 
		sugarWidget.freshdeskWidget.options.application_resources = null;
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
		init_reqs = [{
				resource: "service/v4/rest.php",
				method:"post",
				body:session_body.interpolate({username: sugarWidget.sugarBundle.username, password: sugarWidget.sugarBundle.password}),
				content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
				on_failure: sugarWidget.processFailure,
				on_success: function(evt){
					sugarWidget.handleSessionSuccess(evt)
				}
			}];		
		sugarWidget.freshdeskWidget.options.application_content = null; 
		sugarWidget.freshdeskWidget.options.application_resources = init_reqs;
		sugarWidget.freshdeskWidget.display();
	},

	handleSessionSuccess:function(evt){
		responseText = evt.responseText;
		responseText = sugarWidget.removeRequestKeyword(responseText);
		resJ = jQuery.parseJSON(responseText);
		if (resJ.number != undefined && (resJ.number == 10)){
			this.freshdeskWidget.alert_failure("Please verify your Sugar credentials and try again.")
			jQuery("#sugarcrm_widget").removeClass('loading-fb');
		}
		else{
			Cookie.update("sugar_session", resJ.id);
			sugarWidget.get_sugar_contact();			
		}
	},

	get_sugar_contact:function(){
		var entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"#{session}","module_name":"Contacts","query":"#{email_query}","order_by":"", "offset":0,"select_fields":[],"link_name_to_fields_array":[],"max_results":"","deleted":0}';
		init_reqs = [{
			resource: "service/v4/rest.php",
			method:"post",	
			body:entry_list_body.interpolate({session: Cookie.retrieve("sugar_session")||"", email_query: "contacts.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address ='"+ sugarWidget.sugarBundle.reqEmail +"')"}),
			content_type: "", //Sugar accepts a mix of key-value pairs and json data as an input param as given in the above session_body variable. so content_type will not be json.
			on_failure: sugarWidget.processFailure,
			on_success: sugarWidget.handleContactSuccess.bind(this)
		}];
		sugarWidget.freshdeskWidget.options.application_content = null; 
		sugarWidget.freshdeskWidget.options.application_resources = init_reqs;
		sugarWidget.freshdeskWidget.display();

	},

	removeRequestKeyword:function(responseText){
		return responseText.replace(/request{/g,"{");	
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


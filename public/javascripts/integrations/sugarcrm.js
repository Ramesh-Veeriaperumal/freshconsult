var SugarWidget = Class.create();
SugarWidget.prototype= {

	SUGAR_CONTACT:new Template(
			'<div class="title">' +
				'<div class="name">' +
					'<span id="contact-name"></span><br />' +
				    '<span id="contact-desig"></span>'+
			    '</div>' + 
				'<div id="multiple-contacts">' +
					'<div class="toolbar_pagination">'+ 
						'<a class="disabled prev_page"><span></span></span>' +
						'<a class="next_page" rel="next"><span></span></a>' +
					'</div>' +
			    '</div>' + 
		    '</div>' + 
		    '<hr/>'+
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
			'<div class="external_link"><a target="_blank" id="crm-view">View in SugarCRM</a></div>'),

	SUGAR_CONTACT_NA:new Template(
		'<div class="title">' +
			'<div class="name"  id="contact-na"></div>'+
		'</div>'),

	
	initialize:function(sugarBundle){
		jQuery("#sugarcrm_widget").addClass('loading-fb');
		sugarWidget = this;
		this.sugarBundle = sugarBundle;
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
			console.log(sugar_session);
			if(sugar_session == "" || sugar_session == null){
				sugarWidget.get_sugar_session(sugarWidget.get_sugar_contact);
			}
			else{
				sugarWidget.get_sugar_contact();
			}
		
		}
		//if(loadInline) this.convertToInlineWidget();
	},

	handleContactSuccess:function(resData){
		responseText = resData.responseText
		responseText = sugarWidget.removeRequestKeyword(responseText);
		resJ = jQuery.parseJSON(responseText);
		sugarWidget.response = resJ;
		//Handle Session Timeout
		if (resJ.number != undefined && resJ.number == 11){
				sugarWidget.get_sugar_session(sugarWidget.get_sugar_contact);
				return;
		}
		sugarWidget.renderContactWidget();
		if (resJ.result_count > 0) {
				//renderContact
				if(resJ.result_count == 1){
					entry_list = resJ.entry_list[0];
					sugarWidget.renderContact(entry_list);

					jQuery('#multiple-contacts').hide();
				}
				else if(resJ.result_count > 1){
					jQuery('#multiple-contacts').show();
					sugarWidget.contactChanged(0);
				}

		} else{
			sugarWidget.renderContactNa();
			jQuery('#contact-na').text('Cannot find requester in SugarCRM');
			//sugarWidget.renderContactAddForm();

		}
	},

	renderContact:function(entry_list){

		//sugarWidget.renderContactWidget();
		contactJson = entry_list.name_value_list;
		fullName = contactJson.name.value;
		title = contactJson.title.value;
		account = (contactJson.account_name == undefined) ? "" : contactJson.account_name.value;
		desig = (title != "" && account != "" ) ? (title + ", " + account) : (title + account)
		address = sugarWidget.get_formatted_address(contactJson);
		phone = contactJson.phone_work.value;
		mobile = contactJson.phone_mobile.value;
		department = contactJson.department.value;
		contactLink = sugarWidget.sugarBundle.domain + "/" + "index.php?action=ajaxui#ajaxUILoc=index.php%3Fmodule%3DContacts%26action%3DDetailView%26record%3D"+entry_list.id
		jQuery('#sugar-contact-widget').show();
		jQuery('#contact-name').html('<b>'+fullName+'</b>');
		jQuery('#contact-desig').text(desig);
		(address != "") ? (jQuery('#contact-address').html(address).show()) : (jQuery('#crm-contact').hide()) ;
		(phone != "") ? jQuery('#contact-phone').text(phone) : (jQuery('#crm-phone').hide()) ;
		(mobile != "") ? jQuery('#contact-mobile').text(mobile) : (jQuery('#crm-mobile').hide()) ;
		(department != "") ? jQuery('#contact-dept').text(department) : (jQuery('#crm-dept').hide()) ;
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

			//Changing the Next and Previous
			if (value > 0) {
				jQuery("#multiple-contacts .prev_page").removeClass("disabled").attr("href","javascript:sugarWidget.contactChanged(" + (value - 1) + ")");
			} else {
				jQuery("#multiple-contacts .prev_page").addClass("disabled").attr("href", "javascript:void()");
			}

			if (value >= sugarWidget.response.entry_list.length - 1) {
				jQuery("#multiple-contacts .next_page").addClass("disabled").attr("href", "javascript:void()");
			} else {
				jQuery("#multiple-contacts .next_page").removeClass("disabled").attr("href","javascript:sugarWidget.contactChanged(" + (value + 1) + ")");
			}
		}
		
	},

	renderContactNa:function(){
		sugarWidget.freshdeskWidget.options.application_content = function(){ return sugarWidget.SUGAR_CONTACT_NA.evaluate({});	} 
		sugarWidget.freshdeskWidget.options.application_resources = null;
		sugarWidget.freshdeskWidget.display();
		
	},

	renderContactWidget:function(){
		sugarWidget.freshdeskWidget.options.application_content = function(){ return sugarWidget.SUGAR_CONTACT.evaluate({});	} 
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
				content_type: "",
				on_failure: sugarWidget.processFailure,
				on_success: function(evt){
					responseText = evt.responseText;
					responseText = sugarWidget.removeRequestKeyword(responseText);
					resJ = jQuery.parseJSON(responseText);
					Cookie.update("sugar_session", resJ.id);
					callBack();			
				}
			}];		
		sugarWidget.freshdeskWidget.options.application_content = null; 
		sugarWidget.freshdeskWidget.options.application_resources = init_reqs;
		sugarWidget.freshdeskWidget.display();
	},

	get_sugar_contact:function(){
		var entry_list_body = 'method=get_entry_list&input_type=JSON&response_type=JSON&rest_data={"session":"#{session}","module_name":"Contacts","query":"#{email_query}","order_by":"", "offset":0,"select_fields":[],"link_name_to_fields_array":[],"max_results":"","deleted":0}';
		init_reqs = [{
			resource: "service/v4/rest.php",
			method:"post",
			body:entry_list_body.interpolate({session: Cookie.retrieve("sugar_session")||"", email_query: "contacts.id in (SELECT eabr.bean_id FROM email_addr_bean_rel eabr JOIN email_addresses ea ON (ea.id = eabr.email_address_id) WHERE eabr.deleted=0 AND ea.email_address ='"+ sugarWidget.sugarBundle.reqEmail +"')"}),
			content_type: "",
			on_failure: sugarWidget.processFailure,
			on_success: sugarWidget.handleContactSuccess.bind(this)
		}];
		sugarWidget.freshdeskWidget.options.application_content = null; 
		sugarWidget.freshdeskWidget.options.application_resources = init_reqs;
		sugarWidget.freshdeskWidget.display();

	},

	removeRequestKeyword:function(responseText){
		return responseText.replace(/request{/g,"{");	
	}


}
sugarWidget = new SugarWidget(sugarcrmBundle);


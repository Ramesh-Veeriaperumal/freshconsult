var SugarWidget = Class.create();
SugarWidget.prototype= {

	SUGAR_CONTACT:new Template(
		'<div id="sugarcrm-widget">' +
			'<img src="/images/integrations/sugar_icon.png"></img>'+
			'<div id="multiple-contacts" class="field half_width left hide">' +
			    '<label>Returned Contacts</label> ' +
			    '<select class="full" id="sugar-contacts" onchange="sugarWidget.contactChanged(this.options[this.selectedIndex].value)"></select> ' +
			    '<hr/>'+
		    '</div>' + 
		    '<div id = "sugar-contact-widget">' +
			    '<span id="contact-name"></span><br />'+
			    '<span id="contact-desig"></span>'+
			    '<a target="_blank" id="sugar-view">View in SugarCRM</a></div>'+
			    '<hr/>'+
			    '<div id = "sugar-contact">' +
				    '<label>Contact</label>' +
				    '<span id="contact-address"></span>'+
			    '</div>'+
			    '<div id = "sugar-phone">' +
				    '<label>Phone</label>' +
				    '<span id="contact-phone"></span>'+
				'</div>'+
				'<div id = "sugar-mobile">' +
				    '<label>Mobile</label>' +
				    '<span id="contact-mobile"></span>'+
				'</div>'+
				'<div id = "sugar-dept">' +
				    '<label>Department</label>' +
				    '<span id="contact-dept"></span>'+
				'</div>'+
			'</div>'+
	    '</div>'),

	SUGAR_CONTACT_NA:new Template(
		'<div id="sugarcrm-contact-na">' +
			'<img src="/images/integrations/sugar_icon.png"></img>'+
			'<span id = "contact-na"> </span>'+
		'</div>'),

	
	initialize:function(sugarBundle){
		console.log(sugarBundle)
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
		sugarWidget.renderContactWidget();
		if (resJ.result_count > 0) {
			//Handle Session Timeout
			if (resJ.number != undefined && resJ.number == 11){
				sugarWidget.get_sugar_session(sugarWidget.get_sugar_contact);
			}else{
				//renderContact
				if(resJ.result_count == 1){
					entry_list = resJ.entry_list[0];
					sugarWidget.renderContact(entry_list);
				}
				else if(resJ.result_count > 1){
					jQuery('#multiple-contacts').show();
					dropDownBox = jQuery('#sugar-contacts');
					var newEntityOption = new Element("option");
					newEntityOption.value = -1;
					newEntityOption.innerHTML = "Select a contact to view";
					dropDownBox.append(newEntityOption);

					for(var i=0; i<resJ.result_count; i++){
						var newEntityOption = new Element("option");
						newEntityOption.value = i;
						newEntityOption.innerHTML = resJ.entry_list[i].name_value_list.name.value;
						dropDownBox.append(newEntityOption);

					}
				}
				
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
		(address != "") ? (jQuery('#contact-address').html(address).show()) : (jQuery('#sugar-contact').hide()) ;
		(phone != "") ? jQuery('#contact-phone').text(phone) : (jQuery('#sugar-phone').hide()) ;
		(mobile != "") ? jQuery('#contact-mobile').text(mobile) : (jQuery('#sugar-mobile').hide()) ;
		(department != "") ? jQuery('#contact-dept').text(department) : (jQuery('#sugar-dept').hide()) ;
		jQuery('#sugar-view').attr("href",contactLink);
	},

	contactChanged:function(value){
		if(value == -1){
			jQuery('#sugar-contact-widget').hide();
			jQuery('#sugar-contact').hide();
			jQuery('#sugar-phone').hide();
			jQuery('#sugar-mobile').hide();
			jQuery('#sugar-dept').hide();
		}else{
			entry_list = sugarWidget.response.entry_list[value];
			sugarWidget.renderContact(entry_list);
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


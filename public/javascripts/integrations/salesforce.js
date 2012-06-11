var SalesforceWidget = Class.create();
SalesforceWidget.prototype= {

	SALESFORCE_CONTACT:new Template(
			'<span class="contact-type hide">#{contactType}</span>' +
			'<div class="title">' +
				'<div class="salesforce-name">' +
					'<span id="contact-name">#{contactName}</span><br />' +
				    '<span id="contact-desig">#{contactDesig}</span>'+
			    '</div>' + 
		    '</div>' + 
		    '<div class="field half_width">' +
		    	'<div id="crm-contact">' +
				    '<label>Contact</label>' +
				    '<span id="contact-address">#{contactAddress}</span>' +
			    '</div>'+	
		    	'<div  id="crm-dept">' +
				    '<label>Department</label>' +
				    '<span id="contact-dept">#{contactDept}</span>' +
			    '</div>'+	
		    '</div>'+
		    '<div class="field half_width">' +
		    	'<div  id="crm-phone">' +
				    '<label>Phone</label>' +
				    '<span id="contact-phone">#{contactPhone}</span>'+
			    '</div>' +
				'<div id="crm-mobile">' +
				    '<label>Mobile</label>' +
				    '<span id="contact-mobile">#{contactMobile}</span>'+
				'</div>' +
			'</div>'+
			'<div class="external_link"><a id="search-back" href="javascript:salesforceWidget.renderSearchResults();"> &laquo; Back </a><a target="_blank" id="crm-view" href="#{contactLink}">View <span id="crm-contact-type">#{contactType}</span> in Salesforce</a></div>'),

	SALESFORCE_CONTACT_NA:new Template(
		'<div class="title">' +
			'<div class="salesforce-name"  id="contact-na">Cannot find requester in Salesforce</div>'+
		'</div>'),

	SALESFORCE_SEARCH_RESULTS:new Template(
		'<div class="title">' +
			'<div id="number-returned" class="salesforce-name"> #{resLength} results returned for #{requester} </div>'+
			'<div id="search-results">#{resultsData}</div>'+
		'</div>'),

	initialize:function(salesforceBundle){
		jQuery("#salesforce_widget").addClass('loading-fb');
		salesforceWidget = this;
		this.salesforceBundle = salesforceBundle;
		var init_reqs = [];

		if(salesforceBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				application_id:salesforceBundle.application_id,
				integratable_type:"crm",
				anchor:"salesforce_widget",
				app_name:"salesforce",
				auth_type: "OAuth",
				oauth_token: salesforceBundle.token,
				domain:salesforceBundle.domain,
				ssl_enabled:salesforceBundle.ssl_enabled || "false",
				login_content: null,
				application_content: null,
				application_resources:null
			});
			if(salesforceBundle.reqEmail == ""){
			salesforceWidget.freshdeskWidget.alert_failure('Email not available for this requester. Please make sure a valid Email is set for this requester ');
			jQuery("#salesforce_widget").removeClass('loading-fb');
			}
			else{
				salesforceWidget.get_contact();	
			}
			
		}
	},	

	get_contact:function(){
		var sosl = encodeURIComponent("FIND {" + salesforceWidget.salesforceBundle.reqEmail + "} IN EMAIL FIELDS RETURNING Contact(Account.Name, AccountId, Phone, Id, Department, Email, isDeleted, Name, MailingCity, MailingCountry, MailingState, MailingStreet, MobilePhone, OwnerId, Title ), Lead(Id, City, Company, IsConverted, ConvertedAccountId, ConvertedContactId, Country, Name, MobilePhone, Phone, State, Status, Street, Title)");
		init_reqs = [{
			domain: salesforceBundle.domain,
			resource: "services/data/v20.0/search?q="+sosl,
			content_type: "application/json",
			on_failure: salesforceWidget.processFailure,
			on_success: salesforceWidget.handleContactSuccess
		}];
		salesforceWidget.freshdeskWidget.options.application_content = null; 
		salesforceWidget.freshdeskWidget.options.application_resources = init_reqs;
		salesforceWidget.freshdeskWidget.display();

	},

	handleContactSuccess:function(response){
		resJson = response.responseJSON;
		salesforceWidget.response = resJson;
		if (resJson.length > 0) {
			//renderContact
			if(resJson.length == 1){
				contact = resJson[0];
				salesforceWidget.renderContact(contact);
				jQuery('#multiple-contacts').hide();
				jQuery('#search-back').hide();
			}
			else if(resJson.length > 1){
				salesforceWidget.renderSearchResults();
			}
		}

		else{
			salesforceWidget.renderContactNa();
		}
		jQuery("#salesforce_widget").removeClass('loading-fb');
	},

	renderContact:function(contact){
		title = contact.Title;
		var cLink = salesforceWidget.salesforceBundle.domain +"/"+contact.Id;
		fullName = "<a target='_blank' href='" + cLink  +"'>"+contact.Name+"</a>";
		phone = contact.Phone;
		mobile = contact.MobilePhone;
		if(contact.attributes.type == "Contact"){
			account = (contact.Account) ? contact.Account.Name : null;
			department = contact.Department;
			address = salesforceWidget.getFormattedAddress(contact.MailingStreet, contact.MailingState, contact.MailingCity, contact.MailingCountry);
		}
		else if(contact.attributes.type == "Lead"){
			account = (contact.Company) ? (contact.Company) : null;
			address = salesforceWidget.getFormattedAddress(contact.Street, contact.State, contact.City, contact.Country);
			department = null;
		}
		title = (title) ? (title) : "";
		account = (account) ? (account) : "";
		desig = (title!="" && account!="") ? (title + ", " + account) : (title + account);
		var cPhone = (phone) ? phone : "N/A";
		var cMobile = (mobile) ? mobile : "N/A";
		var cDept = (department) ? department : "N/A" ;
		var cAddress = (address) ? address : "N/A";
		var cType = contact.attributes.type;
		var eval_params = {contactName: fullName, contactDesig: desig, contactPhone: cPhone, contactMobile: cMobile, contactDept: cDept, contactAddress: cAddress, contactType: cType, contactLink: cLink};

		salesforceWidget.renderContactWidget(eval_params);
		jQuery('#salesforce_widget .contact-type').show();

	},

	renderSearchResults:function(){
		var salesforceResults="";
		for(var i=0; i<salesforceWidget.response.length; i++){
			salesforceResults += '<a href="javascript:salesforceWidget.contactChanged(' + i + ')">'+salesforceWidget.response[i].Name+'</a><br/>';
		}
		var results_number = {resLength: salesforceWidget.response.length, requester: salesforceWidget.salesforceBundle.reqEmail, resultsData: salesforceResults};
		salesforceWidget.renderSearchResultsWidget(results_number);
	},

	contactChanged:function(value){
		contact = salesforceWidget.response[value];
		salesforceWidget.renderContact(contact);
	},

	getFormattedAddress:function(street, state, city, country){
		street = (street) ? (street + "<br />")  : "";
		state = (state) ? (state + "<br />")  : "";
		city = (city) ? (city)  : "";
		country = (country) ? (city + ", " + country)  : city;
		address = street + state + country;
		address = (address == "") ? null : address
		return address;
	},

	renderContactWidget:function(eval_params){
		salesforceWidget.freshdeskWidget.options.application_content = function(){ return salesforceWidget.SALESFORCE_CONTACT.evaluate(eval_params);	} 
		salesforceWidget.freshdeskWidget.options.application_resources = null;
		salesforceWidget.freshdeskWidget.display();
	},

	renderSearchResultsWidget:function(results_number){
		salesforceWidget.freshdeskWidget.options.application_content = function(){ return salesforceWidget.SALESFORCE_SEARCH_RESULTS.evaluate(results_number);} 
		salesforceWidget.freshdeskWidget.options.application_resources = null;
		salesforceWidget.freshdeskWidget.display();
	},

	renderContactNa:function(){
		salesforceWidget.freshdeskWidget.options.application_content = function(){ return salesforceWidget.SALESFORCE_CONTACT_NA.evaluate({});} 
		salesforceWidget.freshdeskWidget.options.application_resources = null;
		salesforceWidget.freshdeskWidget.display();
	},

	processFailure:function(evt){
		if (evt.status == 401) {
			//salesforceWidget.get_access_token();
			salesforceWidget.freshdeskWidget.refresh_access_token(function(){
				if(salesforceWidget.freshdeskWidget.options.oauth_token){
				salesforceWidget.get_contact();	
			}
			else{
				salesforceWidget.freshdeskWidget.alert_failure('Unable to connect to Salesforce. Please try again later.')
			}	
			});

		}
	}
}



salesforceWidget = new SalesforceWidget(salesforceBundle);

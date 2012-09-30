var SalesforceWidget = Class.create();
SalesforceWidget.prototype= {

	initialize:function(salesforceBundle){
		jQuery("#salesforce_widget").addClass('loading-fb');
		salesforceWidget = this;
		salesforceBundle.app_name = "Salesforce";
		salesforceBundle.integratable_type = "crm";
		salesforceBundle.auth_type = "OAuth";
		this.salesforceBundle = salesforceBundle;
		freshdeskWidget = new Freshdesk.CRMWidget(salesforceBundle, this);
	},

	get_contact_request: function() {
		var sosl = encodeURIComponent("FIND {" + this.salesforceBundle.reqEmail.replace(/\-/g,'\\-') + "} IN EMAIL FIELDS RETURNING Contact(" + this.salesforceBundle.contactFields + "), Lead(" + this.salesforceBundle.leadFields + ")");
		return { resource: "services/data/v20.0/search?q="+sosl };
	},

	parse_contact: function(resJson){
		contacts = [];
		resJson.each( function(contact) {
			title = contact.Title;
			var cLink = this.salesforceBundle.domain +"/"+contact.Id;
			fullName = contact.Name;
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
			contacts.push({name: fullName, designation: desig, phone: cPhone, mobile: cMobile, department: cDept, address: cAddress, type: cType, url: cLink});
		});
		return contacts;
	},

	getFormattedAddress:function(street, state, city, country){
		street = (street) ? (street + "<br />")  : "";
		state = (state) ? (state + "<br />")  : "";
		city = (city) ? (city)  : "";
		country = (country) ? (city + ", " + country)  : city;
		address = street + state + country;
		address = (address == "") ? null : address
		return address;
	}
}

salesforceWidget = new SalesforceWidget(salesforceBundle);
//update widgets inner join applications on applications.id = widgets.application_id set script=replace(script, " token:", "oauth_token:") where applications.name="salesforce";

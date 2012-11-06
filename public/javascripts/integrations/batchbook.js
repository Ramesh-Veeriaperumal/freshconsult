var BatchbookWidget = Class.create();
BatchbookWidget.prototype= {

	initialize:function(batchbookBundle){
		jQuery("#batchbook_widget").addClass('loading-fb');
		batchbookWidget = this;
		batchbookBundle.app_name = "Batchbook";
		batchbookBundle.widget_name = "batchbook_widget";
		batchbookBundle.username = batchbookBundle.k;
		this.batchbookBundle = batchbookBundle;
		freshdeskWidget = new Freshdesk.CRMWidget(batchbookBundle, batchbookWidget);
	},

	get_contact_request: function() {
		return {resource: "service/people.json?email=" + this.batchbookBundle.reqEmail};
	},	

	parse_contact: function(resJson){
	contacts = [];
	resJson.each( function(contact) {
		bAddressAvailableForDisplay = false; 
		type = contact.person ? "Person" : "Company";
		contact = contact.person || contact.company;
		title = contact.title;
		var cLink = "http://" + this.batchbookBundle.domain + "/contacts/show/" + contact.id;
		var companyLink = contact.company_id ? ("http://" + this.batchbookBundle.domain + "/contacts/show/" + contact.company_id) : null;
		fullName = (contact.first_name || "") + " " +(contact.last_name || "");
		companyName = contact.company;
		companyId = contact.company_id;
		if(contact.locations)
		{
			var primaryIndex = -1, workIndex = -1, homeIndex = -1;
			for(var i=0; i<contact.locations.length; i++){
				if(contact.locations[i].location.primary)
					primaryIndex = i;
				if((contact.locations[i].location.label == "work") || (contact.locations[i].location.label == "main"))
					workIndex = i;
				if(contact.locations[i].location.label == "home")
					homeIndex = i;
			}
			 
			phone = contact.locations[primaryIndex].location.phone;
			mobile = contact.locations[primaryIndex].location.cell;
			
			street_1 = contact.locations[primaryIndex].location.street_1;
			street_2 = contact.locations[primaryIndex].location.street_2;
			 
			if(isValidStreet(street_1) || isValidStreet(street_2)){
				 
				street = (isValidStreet(street_1) ? (street_1 + ", " ) : "") + (isValidStreet(street_2) ? street_2 : "") ;
				if(typeof(street)!='string' || street.length==0)
					street = null;
				city = contact.locations[primaryIndex].location.city;
				state = contact.locations[primaryIndex].location.state;
				country = contact.locations[primaryIndex].location.country;
				bAddressAvailableForDisplay = true;
				addressType = DEFAULT_ADDRESS;
			}
			 
			if((workIndex != -1) && (workIndex != primaryIndex)){
				 
				newPhone = contact.locations[workIndex].location.phone;
				newMobile = contact.locations[workIndex].location.cell;
				phone = phone || (newPhone ? (newPhone + workMark) : null);
				mobile = mobile || (newMobile ? (newMobile + workMark) : null);
				street_1 = contact.locations[workIndex].location.street_1;
				street_2 = contact.locations[workIndex].location.street_2;
				if(!bAddressAvailableForDisplay && (isValidStreet(street_1) || isValidStreet(street_2))){
					street = (isValidStreet(street_1)? (street_1 + ", " ) : "") + (isValidStreet(street_2)?street_2:"");
					if(typeof(street)!='string' || street.length==0)
						street = null;
					city = contact.locations[workIndex].location.city;
					state = contact.locations[workIndex].location.state;
					country = contact.locations[workIndex].location.country;
					bAddressAvailableForDisplay = true;
					addressType = WORK_ADDRESS;
				}
			}
			 
			if((homeIndex != -1) && (homeIndex != primaryIndex)){
				 
				newPhone = contact.locations[homeIndex].location.phone;
				newMobile = contact.locations[homeIndex].location.cell;
				phone = phone || (newPhone ? (newPhone + homeMark) : null);
				mobile = mobile || ( newMobile ? (newMobile + homeMark) : null);
				street_1 = contact.locations[homeIndex].location.street_1;
				street_2 = contact.locations[homeIndex].location.street_2;
				if(!bAddressAvailableForDisplay && (isValidStreet(street_1) || isValidStreet(street_2))){
					street = (isValidStreet(street_1)? (street_1 + ", " ) : "") + (isValidStreet(street_2)?street_2:"");
					if(typeof(street)!='string' || street.length==0)
						street = null;
					city = contact.locations[homeIndex].location.city;
					state = contact.locations[homeIndex].location.state;
					country = contact.locations[homeIndex].location.country;
					bAddressAvailableForDisplay = true;
					addressType = HOME_ADDRESS;
				}
			}


		}
		 
		address = bAddressAvailableForDisplay ? batchbookWidget.getFormattedAddress(street, city, state, country) : null;
		_address_type_span = "";
		if(bAddressAvailableForDisplay){
			if(addressType == WORK_ADDRESS)
				_address_type_span = workMark;
			else if(addressType == HOME_ADDRESS)
				_address_type_span = homeMark;
		}
		 
		title = (title) ? (title) : (companyLink ? "Works" : "") ;
		var cPhone = (phone) ? phone : "N/A";
		var cMobile = mobile ? mobile : "N/A";
		var cAddress = (address) ? address : "N/A";
		var cType = type;
		 
		contacts.push({	name: fullName,
						url: cLink,
						designation: title,
						company: companyName,
						company_id: companyId,
						company_url: companyLink,
						address: cAddress,
						address_type_span: _address_type_span,
						phone: cPhone,
						mobile: cMobile
					});
		});
	
	return contacts;
	},

	getFormattedAddress:function(street, city, state, country){
		street = (street) ? (street + "<br />")  : "";
		city = (city) ? (city)  : "";
		state = (state) ? (state)  : "";
		country = (country) ? (country)  : "";

		line1 = street;
		line2 = (	city
					+ ((city.length>0 && state.length>0) ? ", " : "")
					+ (state)
					+ ((city.length>0 || state.length>0) ? "<br/>" : "")
				);
		line3 = country;

		address = line1 + line2 + line3;
		address = (address == "") ? null : address ;
		return address;
	}
};

workMark = "<span title='Work' class='contact-location'>(W)</span>";
homeMark = "<span title='Home' class='contact-location'>(H)</span>";
var DEFAULT_ADDRESS = 0, WORK_ADDRESS = 1, HOME_ADDRESS = 2;

var batchbookWidget = new BatchbookWidget(batchbookBundle);

function isValidStreet(s){
	if(s){
		s = s.replace(/^\s+|\s+$/g, "");
		if (s.length>0)
			return true;
	}
	return false;
}




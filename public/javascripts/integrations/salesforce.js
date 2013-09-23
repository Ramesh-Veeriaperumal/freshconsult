var SalesforceWidget = Class.create();
SalesforceWidget.prototype= {

	initialize:function(salesforceBundle){
		jQuery("#salesforce_widget").addClass('loading-fb');
		salesforceWidget = this;
		salesforceBundle.app_name = "Salesforce";
		salesforceBundle.integratable_type = "crm";
		salesforceBundle.auth_type = "OAuth";
		salesforceBundle.handleRender = true;
		salesforceBundle.oauth_token = salesforceBundle.token;
		this.salesforceBundle = salesforceBundle;
		this.contactFields = ["Name"];
		this.leadFields=["Name"];
		freshdeskWidget = new Freshdesk.CRMWidget(salesforceBundle, this);
	},

	get_contact_request: function() {
		var contactfields = "Name";
		var leadfields = "Name";
		if(this.salesforceBundle.contactFields!=undefined)
		{
			contactfields = this.salesforceBundle.contactFields.split(",");
			for (var i=0;i<contactfields.length;i++){
				//fetching details for address fields
				if(contactfields[i] == "Address") {
					contactfields.splice(i, 1);
					var addr_arr= ["MailingStreet","MailingCity","MailingState","MailingCountry","MailingPostalCode"];
					for(j=0;j<addr_arr.length;j++){
				 		contactfields.splice(i, 0,addr_arr[j]);
				 	}
				}
			}
		}
		if(this.salesforceBundle.leadFields!=undefined)
		{
			leadfields = this.salesforceBundle.leadFields.split(",");
			for (var i=0;i<leadfields.length;i++){
				//fetching details for address fields
				if(leadfields[i] == "Address") {
				 	leadfields.splice(i, 1);
					var addr_arr= ["Street","City","State","Country","PostalCode"];
					for(j=0;j<addr_arr.length;j++){
				 		leadfields.splice(i, 0,addr_arr[j]);
				 	}
				}
			}
		}

		contactfields = this.removeDuplicate(contactfields);
		leadfields = this.removeDuplicate(leadfields);

		var custEmail = escape(this.salesforceBundle.reqEmail);
		var sosl = "FIND {" + custEmail.replace(/\-/g,'\\-') + "} IN EMAIL FIELDS RETURNING Contact(" + contactfields + "), Lead(" + leadfields + ")";
		return { rest_url: "services/data/v20.0/search?q="+sosl };
	},
	removeDuplicate: function(data_arr){
		var data_hash={"Id":"Id"};//Id added by default for url construction.
		for(var i=0;i<data_arr.length;i++){
			data_hash[data_arr[i]]=data_arr[i];
		}
		return_arr = new Array();
		for(key in data_hash){
			return_arr.push(key);
		}
		return return_arr;
	},
	parse_contact: function(resJson){
		var contacts =[];
		resJson.each(function(contact) {
			var cLink = this.salesforceBundle.domain +"/"+contact.Id;
			var sfcontact ={};
			sfcontact['url'] = cLink;//This sets the url to salesforce on name
			sfcontact['type'] = contact.attributes.type;
			if(contact.attributes.type == "Contact"){
				if(this.salesforceBundle.contactFields!=undefined){
					contactfields = this.salesforceBundle.contactFields.split(",");
					for (var i=0;i<contactfields.length;i++){
						if(contactfields[i]=="Address"){
							sfcontact[contactfields[i]]=this.salesforceWidget.getAddress(contact.MailingStreet,contact.MailingState,contact.MailingCity,contact.MailingCountry);
						}
						else{
							sfcontact[contactfields[i]] = contact[contactfields[i]];
						}
					}
				}
			}
			else{
				if(this.salesforceBundle.leadFields!=undefined){
					leadfields = this.salesforceBundle.leadFields.split(",");
					for (var i=0;i<leadfields.length;i++){
						if(leadfields[i]=="Address"){
							sfcontact[leadfields[i]]=this.salesforceWidget.getAddress(contact.Street,contact.State,contact.City,contact.Country);
						}
						else{
							sfcontact[leadfields[i]] = contact[leadfields[i]]
						}
					}
				}
			}
			contacts.push(sfcontact);
		});
		return contacts;

	},
	getAddress:function(street, state, city, country){
		var address="";
		street = (street) ? (street + ", ")  : "";
		state = (state) ? (state + ", ")  : "";
		city = (city) ? (city)  : "";
		country = (country) ? (city + ", " + country)  : city;
		address = street + state + country;
		address = (address == "") ? null : address
		return address;
	},
	getTemplate:function(eval_params,crmWidget){
		var contactTemplate ="";
		var fields = this.salesforceBundle.contactFields.split(",");
		if(eval_params.type!="Contact"){
			fields = this.salesforceBundle.leadFields.split(",");
		}
		for(var i=0;i<fields.length;i++){
			var value = eval_params[fields[i]];
			if(fields[i]=="Name"){
				continue;
			}
			field_name =fields[i].split('__');//for custom fields to get the label
   		if(field_name[1] !=undefined){
   				fields[i] = field_name[1];
   			}
			if(value==null || value == undefined){
				value ="N/A";
			}
			if(i==4){
				contactTemplate+='<span class="hide" id="'+eval_params.type+'_all_data">';
   			}
   			contactTemplate+= '<div class="salesforce-widget">' +
		    			'<div class="clearfix">' +
					    '<span>'+fields[i]+':</span>' +
				    	'<label id="contact-'+fields[i]+'">'+value+'</label>' +
			    		'</div></div>';	
		}
	    if(fields.length>=5){
	    	contactTemplate+='<div id="less_'+eval_params.type+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#more_'+eval_params.type+'_button\').show();jQuery(\'#'+eval_params.type+'_all_data\').addClass(\'hide\');return false;">less</a></div>';
	        contactTemplate+= '</span><div id="more_'+eval_params.type+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#less_'+eval_params.type+'_button\').show();jQuery(\'#'+eval_params.type+'_all_data\').removeClass(\'hide\');return false;" >more</a></div>';
	    }
		return contactTemplate;
	},
	handleRender:function(contacts,crmWidget){
		if ( contacts.length > 0) {
			if(contacts.length == 1){
				this.renderContactWidget(contacts[0],crmWidget);
			}
			else{
				this.renderSearchResults(crmWidget);
			}
		} else {
			crmWidget.renderContactNa();
		}
		jQuery("#"+crmWidget.options.widget_name).removeClass('loading-fb');
	},
	renderContactWidget:function(eval_params,crmWidget){
		var cw = this;
		eval_params.count = crmWidget.contacts.length;
		eval_params.app_name = crmWidget.options.app_name;
		eval_params.widget_name = crmWidget.options.widget_name;
		eval_params.type = eval_params.type?eval_params.type:"" ; // Required
		eval_params.department = eval_params.department?eval_params.department:null;
		eval_params.url = eval_params.url?eval_params.url:"#";
		eval_params.address_type_span = eval_params.address_type_span || " ";
		var contact_fields_template="";
		var contact_fields_template = this.getTemplate(eval_params,crmWidget);

		crmWidget.options.application_html = function(){ return _.template(cw.VIEW_CONTACT, eval_params)+""+contact_fields_template;	} 
		crmWidget.display();
		var obj = this;
		jQuery('#' + crmWidget.options.widget_name).on('click','#search-back', (function(ev){
			ev.preventDefault();
			obj.renderSearchResults(crmWidget);
		}));
	},
	renderSearchResults:function(crmWidget){
		var crmResults="";
		for(var i=0; i<crmWidget.contacts.length; i++){
			crmResults += '<li><a class="multiple-contacts" href="#" data-contact="' + i + '">'+crmWidget.contacts[i].Name+'</a></li>';
		}
		var results_number = {resLength: crmWidget.contacts.length, requester: crmWidget.options.reqEmail, resultsData: crmResults};
		this.renderSearchResultsWidget(results_number,crmWidget);
		var obj = this;
		jQuery('#' + crmWidget.options.widget_name).on('click','.multiple-contacts', (function(ev){
			ev.preventDefault();
			obj.renderContactWidget(crmWidget.contacts[jQuery(this).data('contact')],crmWidget);
		}));
	},
	renderSearchResultsWidget:function(results_number,crmWidget){
		var cw=this;
		results_number.widget_name = crmWidget.options.widget_name;
		crmWidget.options.application_html = function(){ return _.template(cw.CONTACT_SEARCH_RESULTS, results_number);} 
		crmWidget.display();
	},
	VIEW_CONTACT:
		'<div class="title <%=widget_name%>_bg">' +
			'<div class="row-fluid">' +
				'<div id="contact-name" class="span8">'+
				'<div class="search-back <%=(count>1 ? "": "hide")%>"><a id="search-back" href="#"> <i class="arrow-left"></i> </a></div>'+
				'<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title"><%=Name%></a></div>' +
				'<div class="span4"><span class="btn btn-mini btn-primary pull-right"><%=(type || "")%></span></div>'+
		    '</div>' + 
	    '</div>',
	CONTACT_SEARCH_RESULTS:
		'<div class="title <%=widget_name%>_bg">' +
			'<div id="number-returned"><b> <%=resLength%> results returned for <%=requester%> </b></div>'+
			'<div id="search-results"><ul><%=resultsData%></ul></div>'+
		'</div>',
}

salesforceWidget = new SalesforceWidget(salesforceBundle);
//update widgets inner join applications on applications.id = widgets.application_id set script=replace(script, " token:", "oauth_token:") where applications.name="salesforce";

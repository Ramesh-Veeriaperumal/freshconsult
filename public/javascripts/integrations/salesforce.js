var SalesforceWidget = Class.create();
SalesforceWidget.prototype= {

	initialize:function(salesforceBundle){
		jQuery("#salesforce_contacts_widget").addClass('loading-fb');
		salesforceWidget = this;
		salesforceBundle.app_name = "salesforce";
		salesforceBundle.integratable_type = "crm";
		salesforceBundle.auth_type = "NoAuth";
		salesforceBundle.widget_name = "salesforce_contacts_widget";
		salesforceBundle.handleRender = true;
		this.salesforceBundle = salesforceBundle;
		this.contactFields = ["Name"];
		this.leadFields=["Name"];
		this.accountFields=["Name"];
		this.contactInfo = this.mapFieldLabels(salesforceBundle.contactFields,salesforceBundle.contactLabels);
		this.leadInfo = this.mapFieldLabels(salesforceBundle.leadFields,salesforceBundle.leadLabels);
		this.accountInfo = this.mapFieldLabels(salesforceBundle.accountFields,salesforceBundle.accountLabels);
		freshdeskWidget = new Freshdesk.CRMWidget(salesforceBundle, this);
	},
	mapFieldLabels: function(fields,labels){
		var fieldLabels ={}
		var labelsArr = new Array();
		fieldsArr = fields.split(",");
		labelsArr = fieldsArr;//no labels until reenabled,defaults to field-name for existing sf users
		if(labels != undefined && labels.length != 0){
			labelsArr = labels.split(",");
		}
		for (var i=0;i<fieldsArr.length;i++){
			fieldLabels[fieldsArr[i]] = labelsArr[i];
		}
		return fieldLabels
	},

	get_contact_request: function() {
		var requestUrls = [];
		var custEmail = escape(this.salesforceBundle.reqEmail);
		custEmail = custEmail.replace(/\-/g,'\\-')
		requestUrls.push( { type:"contact", value:custEmail } )
		requestUrls.push( { type:"lead", value:custEmail } )
		var custCompany = this.salesforceBundle.reqCompany;
		if( this.salesforceBundle.accountFields && this.salesforceBundle.accountFields.length > 0 ) { //accountFields is configured
			if ( custCompany  && custCompany.length > 0 ) { // make sure company is present 
				custCompany = custCompany.replace(/\W/g,' ').replace(/\s+/g, ' ');
				requestUrls.push( { type:"account", value:{company:custCompany} } )
			}
			else{
				requestUrls.push( { type:"account", value:{email:custEmail} } )
			}
		}
		for(var i=0;i<requestUrls.length;i++){
			requestUrls[i] = {	event:"fetch_user_selected_fields", 
							   	source_url:"/integrations/service_proxy/fetch",
							   	app_name:"salesforce",
							   	payload: JSON.stringify(requestUrls[i]) 
							 }
		}
		this.searchCount = requestUrls.length;
		this.searchResultsCount = 0;
		return requestUrls; 
	},

	parse_contact: function(resJson){
		var contacts =[];
		if(resJson.records)
			resJson=resJson.records;
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
							sfcontact[contactfields[i]] = escapeHtml(this.salesforceWidget.eliminateNullValues(contact[contactfields[i]]));
						}
					}
				}
			}
			else if(contact.attributes.type == "Lead"){
				if(this.salesforceBundle.leadFields!=undefined){
					leadfields = this.salesforceBundle.leadFields.split(",");
					for (var i=0;i<leadfields.length;i++){
						if(leadfields[i]=="Address"){
							sfcontact[leadfields[i]]=this.salesforceWidget.getAddress(contact.Street,contact.State,contact.City,contact.Country);
						}
						else{
							sfcontact[leadfields[i]] = escapeHtml(this.salesforceWidget.eliminateNullValues(contact[leadfields[i]]));
						}
					}
				}
			}
			else{
				if(this.salesforceBundle.accountFields!=undefined){
					accountfields = this.salesforceBundle.accountFields.split(",");
					for (var i=0;i<accountfields.length;i++){
						if(accountfields[i]=="Address"){
							sfcontact[accountfields[i]]=this.salesforceWidget.getAddress(contact.BillingStreet,contact.BillingState,contact.BillingCity,contact.BillingCountry);
						}
						else{
							sfcontact[accountfields[i]] = escapeHtml(this.salesforceWidget.eliminateNullValues(contact[accountfields[i]]));
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
		return escapeHtml(address || "NA");
	},
	getTemplate:function(eval_params,crmWidget){
		var contactTemplate ="";
		var labels = this.contactInfo;
		var fields = this.salesforceBundle.contactFields.split(",");
		if(eval_params.type=="Lead"){
			fields = this.salesforceBundle.leadFields.split(",");
			labels = this.leadInfo;
		}
		if(eval_params.type=="Account"){
			fields = this.salesforceBundle.accountFields.split(",");
			labels = this.accountInfo;
		}
		for(var i=0;i<fields.length;i++){
			var value = eval_params[fields[i]];
			if(i==4){
				contactTemplate+='<span class="hide" id="'+eval_params.type+'_all_data">';
	 			}
			if(fields[i]=="Name"){
				continue;
			}
			if(value==null || value == undefined){
				value ="N/A";
			}
	 			contactTemplate+= '<div class="salesforce-widget">' +
					'<div class="clearfix">' +
						'<span>'+labels[fields[i]]+':</span>' +
					'	<label id="contact-'+fields[i]+'" class="ellipsis tooltip" title="'+value+'">'+value+'</label>' +
					'</div></div>';	
		}
		if(fields.length>=5){
			contactTemplate+='<div id="less_'+eval_params.type+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#more_'+eval_params.type+'_button\').show();jQuery(\'#'+eval_params.type+'_all_data\').addClass(\'hide\');return false;">less</a></div>';
			contactTemplate+= '</span><div id="more_'+eval_params.type+'_button" class="external_link"><a href="#" onclick="jQuery(this).parent().hide();jQuery(\'#less_'+eval_params.type+'_button\').show();jQuery(\'#'+eval_params.type+'_all_data\').removeClass(\'hide\');return false;" >more</a></div>';
		}
		return contactTemplate;
	},
	handleRender:function(contacts,crmWidget){
	  if ( !this.allResponsesReceived() ) 
	    return;
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
			crmResults += '<li><a class="multiple-contacts salesforce-tooltip" title="'+crmWidget.contacts[i].Name+'" href="#" data-contact="' + i + '">'+crmWidget.contacts[i].Name+'</a><span class="contact-search-result-type">'+crmWidget.contacts[i].type+'</span></li>';
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
	allResponsesReceived:function(){
		return (this.searchCount <= ++this.searchResultsCount );
	},
	eliminateNullValues:function(input){
		input = (input == null)? "NA":input
		return input;
	},
	VIEW_CONTACT:
		'<div class="title <%=widget_name%>_bg">' +
			'<div class="row-fluid">' +
				'<div id="contact-name" class="span8">'+
				'<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
				'<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=Name%></a></div>' +
				'<div class="span4 pt3"><span class="contact-search-result-type"><%=(type || "")%></span></div>'+
			'</div>' + 
		'</div>',
	CONTACT_SEARCH_RESULTS:
		'<div class="title <%=widget_name%>_bg">' +
			'<div id="number-returned"><b> <%=resLength%> results for <%=requester%> </b></div>'+
			'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
		'</div>',
}
//update widgets inner join applications on applications.id = widgets.application_id set script=replace(script, " token:", "oauth_token:") where applications.name="salesforce";

var ConstantContactWidget = Class.create();
ConstantContactWidget.prototype= {

	ContactList: '<ContactList id="http://api.constantcontact.com/ws/customers/<%=username%>/lists/<%=list_id%>">'+
						      '<link xmlns="http://www.w3.org/2005/Atom" href="/ws/customers/<%=username%>/lists/<%=list_id%>" rel="self"></link>'+
						      '<OptInSource>ACTION_BY_CUSTOMER</OptInSource>'+
						    '</ContactList>',

	ConstantContactAdd: '<entry xmlns="http://www.w3.org/2005/Atom">'+
											  '<title type="text"> </title>'+
											  '<updated>2008-07-23T14:21:06.407Z</updated>'+
											  '<author></author>'+
											  '<id>data:,none</id>'+
											  '<summary type="text">Contact</summary>'+
											  '<content type="application/vnd.ctct+xml">'+
											    '<Contact xmlns="http://ws.constantcontact.com/ns/1.0/">'+
											      '<EmailAddress><%=email%></EmailAddress>'+
											      '<OptInSource>ACTION_BY_CUSTOMER</OptInSource>'+
											      '<ContactLists>'+
											      '<%=clists%>'+
											      '</ContactLists>'+
											    '</Contact>'+
											  '</content>'+
											'</entry>',

	initialize: function(ccBundle){
		this.ERROR_MAPPER = {401: "Unauthorized account. Try reinstalling the integration addon.", 400: "Invalid request. Try again later.", 404: "Unknown error. Please contact Support", 415: "Unsupported Request 415. Please contact Suport", 500: "Unknown error. Please contact Support"};
		ccWidget = this;
		ccBundle.integratable_type = "email_marketing";
		ccBundle.app_name = "ConstantContact";
		ccBundle.username = ccBundle.token;
		ccBundle.url_token_key = "access_token";
		ccBundle.auth_type = "UAuth";
		ccBundle.domain = "https://api.constantcontact.com/ws/customers/"+ccBundle.uid;
		ccBundle.ssl_enabled = "true";
		ccBundle.requests = {getUserInfo: this.getUserInfo(), getCampaigns: this.getCampaigns(), getAllLists: this.getAllLists()};
		ccBundle.requestForListSub = true;
		this.freshdeskWidget = new Freshdesk.EmailMarketingWidget(ccBundle, this);
	},

	
	getUserInfo: function(){
		contactInfoEndpoint = "contacts?email=#{email}";
		return { rest_url: contactInfoEndpoint.interpolate({email:encodeURIComponent(ccBundle.reqEmail)}), content_type: "application/atom+xml" };
	},

	getCampaigns: function(){
		campaignEventsEndpoint = "contacts/#{contactId}/events/summary";
		return { rest_url: campaignEventsEndpoint, content_type: "application/atom+xml" };
	},

	getAllLists: function(){
		allListsEndpoint = "lists";
		return { rest_url: allListsEndpoint, content_type: "application/atom+xml" }
	},

	getSubscribedLists: function(){
		if(this.contact){
			subListsEndpoint = "contacts/#{contact_id}";
			return { rest_url: subListsEndpoint.interpolate({contact_id: this.contact.id}), content_type: "application/atom+xml" };
		}
	},

	addContact: function(list){
		var contactLists = "";
		for(var i=0; i<list.length; i++){
			contactLists += _.template(this.ContactList, {username: "nathanclassic",  list_id: list[i]});
		}
		contact = _.template(this.ConstantContactAdd, {email: ccBundle.reqEmail, clists: contactLists});
		this.freshdeskWidget.request({
			body: contact,
			method: "post",
			rest_url: "contacts",
			content_type: "application/atom+xml",
			on_success: this.handleAddContact.bind(this),
			on_failure: this.freshdeskWidget.handleFailure
		});
	},

	handleAddContact: function(response){
		entry = XmlUtil.extractEntities(response.responseXML, "entry");
		if(entry.length > 0){
			this.freshdeskWidget.handleUser(response)
		}else{
			this.freshdeskWidget.processFailure("Unable to add the contact to " + icontactBundle.app_name);
			this.freshdeskWidget.exportUser();
		}
	},

	updateSubscription: function(){
		list = []; cList = "";
		jQuery('.lists input:checked').each(function() {
		  list.push($(this).id);
		});
		contact = this.contactDetailResponse;
		contact_entry = XmlUtil.extractEntities(contact, 'ContactLists')[0];
		cList = "<ContactLists>";
		for(var i=0; i<list.length; i++){
			cList += _.template(this.ContactList, {username: "nathanclassic", list_id: list[i]});
		}
		cList += "</ContactLists>";
		doc = XmlUtil.loadXMLString(cList);
		contact_list = doc.getElementsByTagName('ContactLists')[0];
		if(contact_entry)
			jQuery(contact).first().find('ContactLists').replaceWith(contact_list);
		else
			jQuery(contact).first().find('Confirmed').before(contact_list);
		updated_list = contact.getElementsByTagName('entry')[0];
		updateSubscriptionEndpoint = "contacts/#{id}";
		requestBody = (new XMLSerializer()).serializeToString(updated_list);
		this.freshdeskWidget.request({
			method: "put",
			body: requestBody,
			rest_url: updateSubscriptionEndpoint.interpolate({id: this.contact.id}) ,
			content_type: "application/atom+xml",
			on_failure: function(response){
				this.freshdeskWidget.handleFailure(response);
				this.freshdeskWidget.getAllLists();	
			}.bind(this),
			on_success: this.updateSubscriptionSuccess.bind(this)
		});
		jQuery('#' + this.freshdeskWidget.options.widget_name + ' .lists-load').hide();
		jQuery('#' + this.freshdeskWidget.options.widget_name + ' .emailLists').addClass('loading-center');
	},

	updateSubscriptionSuccess: function(response){
		if(response.status == 204){
			this.freshdeskWidget.getAllLists();
		}
		else{
			this.freshdeskWidget.handleFailure(response);
		}
	},

	handleLists: function(response){
		all_lists = []
		response = response.responseXML;
		entries = XmlUtil.extractEntities(response, 'entry');
			for(var i=0; i<entries.length; i++){
				id = XmlUtil.getNodeValue(entries[i], 'id').split("/lists/")[1];
				title = XmlUtil.getNodeValue(entries[i], 'title');
				all_lists.push({"listId": id, "name": title});
			}
		return all_lists;
	},

	handleSubscribedLists: function(response){
		lists = [];
		response = response.responseXML;
		this.contactDetailResponse = response;
		sublists = (XmlUtil.extractEntities(response, 'ContactList'));
		for(i=0; i<sublists.length; i++){
			lists.push(XmlUtil.getNodeAttrValue(sublists[i], 'link', 'href').split("/lists/")[1]);
		}
		return lists;
	},

	handleUser: function(response){
		entry = XmlUtil.extractEntities(response.responseXML, "entry");
		if(entry.length > 0){
			id = (XmlUtil.getNodeValue(entry[0], "id")).split("/contacts/")[1];
			name = (XmlUtil.getNodeValue(entry[0], "Name"));
			since = (XmlUtil.getNodeValue(entry[0], "InsertTime"));
			contact = {"id" : id, "name" : name, "since" : since.replace(/[T|Z]/g, ' ')};
			this.contact = contact;
			return this.contact;
		}
		else{
			this.freshdeskWidget.exportUser();
		}
	},

	handleCampaigns: function(response){
		activities = {}; campaigns = {};
		actions = ["Opens", "Clicks"];
		entry = XmlUtil.extractEntities(response.responseXML, "entry");
		if(entry.length > 0){
			for(i=0; i<entry.length; i++){
				var campActivities = new Array();
				title = (XmlUtil.getNodeValue(entry[i], "Name"));
				id = (XmlUtil.getNodeAttrValue(entry[i], 'Campaign', 'id')).split("/campaigns/")[1];
				action_stmt = {"Clicks": "#{total} links clicked", "Opens": "Opened #{total} times"};
				for( c=0; c<actions.length; c++){
					action_total = XmlUtil.getNodeValue(entry[i], actions[c]);
					action = action_stmt[actions[c]].interpolate({total: action_total});
					campActivities.push({"type": actions[c], "time": action});
				}
				campaigns[id] = {"title": title};	
				activities[id] = campActivities;
				if(_.keys(campaigns).length > 4)
					break;
			}
			return {"campaigns": campaigns, "activities": activities};
		}
		this.freshdeskWidget.handleEmptyCampaigns();   ///Empty campaigns handler
	},

	processFailure: function(response){
		return this.ERROR_MAPPER[response.status] || "Unknown error. Please contact Support." ;
	}

}
ccWidget = new ConstantContactWidget(ccBundle);
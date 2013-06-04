var iContactWidget = Class.create();
iContactWidget.prototype= {
	initialize: function(icontactBundle){
		icontactWidget = this;
		icontactBundle.app_name = "iContact";
		icontactBundle.integratable_type = "email_marketing";
		icontactBundle.domain = icontactBundle.api_url;
		icontactBundle.use_server_password = "true";
		icontactBundle.ssl_enabled = "true";
		icontactBundle.requests = {getUserInfo: this.getUserInfo(), getCampaigns: this.getCampaigns(), getAllLists: this.getAllLists()};
		this.freshdeskWidget = new Freshdesk.EmailMarketingWidget(icontactBundle, this);
	},

	getUserInfo: function(){
		contactInfoEndpoint = "contacts?email=#{email}&status=total";
		return {rest_url: contactInfoEndpoint.interpolate({email: icontactBundle.reqEmail})};
	},

	getCampaigns: function(){
		campaignsEndpoint = "contacts/#{contactId}/actions?actionType=Click,Open,ReleaseSend,Forward,EditSubscription";
		return { rest_url: campaignsEndpoint};
	},

	getAllLists: function(){
		return { rest_url: "lists" };
	},

	getSubscribedLists: function(){
		return this.subscribedLists;
	},

	updateSubscription: function(subscribed, unsubscribed){
		requestBody = [];
		for(i=0; i<subscribed.length; i++){
			requestBody.push({"subscriptionId": (subscribed[i] + "_" + this.contact.id), "status": "normal"});
		}
		for(i=0; i<unsubscribed.length; i++){
			requestBody.push({"subscriptionId": (unsubscribed[i] + "_" + this.contact.id), "status": "unsubscribed"});
		}
		if(requestBody.length > 0){
			subscriptionsEndpoint = "subscriptions";
			this.freshdeskWidget.request({
				body: JSON.stringify(requestBody).replace(/^"|"$/g, '').replace(/\\/g, ''),
				method: "post",
				rest_url: subscriptionsEndpoint,
				on_failure: this.updateFailure.bind(this),
				on_success: this.updateSubscriptionSuccess.bind(this)
			});	
		}
		jQuery('#' + this.freshdeskWidget.options.widget_name + ' .lists-load').hide();
		jQuery('#' + this.freshdeskWidget.options.widget_name + ' .emailLists').addClass('sloading loading-small');
	},

	updateSubscriptionSuccess: function(response){
		resJ = jQuery.parseJSON(response.responseJSON);
		subscriptions = resJ.subscriptions;
		this.freshdeskWidget.listsTmpl = null;
		if(subscriptions.length > 0)
			this.freshdeskWidget.updateSubscriptionNotifier = true;
		else if(resJ.errors || resJ.warnings)
			this.freshdeskWidget.processFailure(resJ.errors || resJ.warnings);
		else
			this.freshdeskWidget.handleFailure(response);
		this.freshdeskWidget.updateSubscriptionNotifier = true;
		this.freshdeskWidget.getCampaigns();
	},

	updateFailure: function(response){
		resJ = jQuery.parseJSON(response.responseJSON);
		if(resJ.errors || resJ.warnings){
			this.freshdeskWidget.processFailure(resJ.errors || resJ.warnings);
			this.freshdeskWidget.updateSubscriptionNotifier = true;
			this.freshdeskWidget.getCampaigns();
		}
	},

	addContact: function(){
		requestBody = [];
		requestBody.push({email: icontactBundle.reqEmail});
		this.freshdeskWidget.request({
			body: JSON.stringify(requestBody).replace(/^"|"$/g, '').replace(/\\/g, ''),
			method: "post",
			rest_url: "contacts",
			on_success: this.handleAddContact.bind(this),
			on_failure: this.freshdeskWidget.handleFailure
		});
	},

	handleAddContact: function(response){
		contact = jQuery.parseJSON(response.responseJSON).contacts;
		if(!contact){
			this.freshdeskWidget.processFailure("Unable to add the contact to " + icontactBundle.app_name);
			this.freshdeskWidget.exportUser();
		}
		else{
			this.freshdeskWidget.handleUser(response);
		}

	},

	handleUser: function(response){
		contacts = jQuery.parseJSON(response.responseJSON).contacts;
		if(contacts.length > 0){
			this.contact = {"id" : contacts[0].contactId, "name" : (contacts[0].firstName + " " + contacts[0].lastName), "since" : contacts[0].createDate};
			return this.contact;
		}
		else{
			this.freshdeskWidget.exportUser();
		}
	},

	handleCampaigns: function(response){
		actions = jQuery.parseJSON(response.responseJSON).actions;
		this.subscribedLists = []; unsubscribedLists = []; messages = [];
		if(actions.length > 0)	{
			activities = {}; campaigns = {};
			for(var i=0; i<actions.length; i++){
				messageId = actions[i].details.messageId;
				type = actions[i].actionType;
				timestamp = actions[i].actionTime || "";
				subject = actions[i].details.subject;
				if(type == "EditSubscription" && actions[i].details.newStatus == "normal")
					this.subscribedLists.push(actions[i].details.listId); 
				else if(type == "EditSubscription" && actions[i].details.newStatus == "unsubscribed"){
					unsubscribedLists.push(actions[i].details.listId.toString());
				}
				else{
					activity = {"type": type, "time": timestamp};
					if(actions[i].details.link)
						activity["link"] = actions[i].details.link;
					(activities[messageId]) ? activities[messageId].push(activity) : activities[messageId] = [activity];
					campaigns[messageId] = {"title": subject};	
					messages.push(messageId);
					if(_.keys(campaigns).length > 4)
						break;
				}
			}
			for(i=0; i<unsubscribedLists.length; i++){
				var index = this.subscribedLists.indexOf(unsubscribedLists[i]);
				this.subscribedLists.splice(index, 1);
			}
			if(messages.length == 0)
				this.freshdeskWidget.handleEmptyCampaigns();
			else{
				return {"campaigns": campaigns, "activities": activities};
			}
				
		}else
		this.freshdeskWidget.handleEmptyCampaigns();
	},

	
	handleLists: function(response){
		return jQuery.parseJSON(response.responseJSON).lists;
	},

	processFailure: function(response){
		return jQuery.parseJSON(response.responseJSON).errors;
	}

}
icontactWidget = new iContactWidget(icontactBundle);
var CampaignMonitorWidget = Class.create();
CampaignMonitorWidget.prototype= {
	initialize: function(cmBundle){
		this.ERROR_MAPPER = {}
		cmWidget = this;
		cmBundle.app_name = "CampaignMonitor";
		cmBundle.integratable_type = "email_marketing";
		cmBundle.domain = 'http://api.createsend.com/api/v3';
		cmBundle.username = cmBundle.api_key;
		cmBundle.ssl_enabled = "true";
		cmBundle.requests = {getAllLists: this.getAllLists()};
		this.freshdeskWidget = new Freshdesk.EmailMarketingWidget(cmBundle, this);
	},

	getCampaignsForEmail: function(){
		listsEmailEndpoint = "clients/#{clientId}/listsforemail.json?email=#{email}";
		return { rest_url: listsEmailEndpoint.interpolate({clientId: cmBundle.client_id, email: cmBundle.reqEmail}), on_success: this.listsForEmailSuccess.bind(this) }
	},

	getAllLists: function(){
		allListsEndpoint = "clients/#{clientId}/lists.json"
		return { rest_url: allListsEndpoint.interpolate({clientId: cmBundle.client_id}) }
	},

	getSubscribedLists: function(){
		subscribedLists = [];
		for(i=0; i<this.subLists.length; i++){
			subscribedLists.push(this.subLists[i].ListID);
		}
		return subscribedLists;
	},

	contactRequest: function(list){
		requestBody = {EmailAddress: cmBundle.reqEmail};
		subscriptionsEndpoint = "subscribers/#{listID}.json";
		return { body: JSON.stringify(requestBody), method: "post", rest_url: subscriptionsEndpoint.interpolate({listID: list}) };
	},

	listsForEmailSuccess: function(response){
		this.lists = response.responseJSON; this.subLists = [];
		if(this.lists.length > 0){
			for(i=0; i<this.lists.length; i++){
				if(this.lists[i].SubscriberState != "Unsubscribed"){
					this.subLists.push(this.lists[i]);
				}
			}
			this.getCampaigns();
		}
		else
			this.freshdeskWidget.exportUser();
	},

	getCampaigns: function(){
		dfd_arr = []; cmWidget.activities = []; 
		for(i=0; i<this.lists.length; i++){
			dfd_arr.push(this.getActivity(this.lists[i].ListID));
		}
		jQuery.when.apply(null, dfd_arr).then(this.handleActivities.bind(this));
	},

	subscribeLists: function(list){
		requestBody = {EmailAddress: cmBundle.reqEmail};
		subscriptionsEndpoint = "subscribers/#{listID}.json";
		return { body: JSON.stringify(requestBody), method: "post", rest_url: subscriptionsEndpoint.interpolate({listID: list}) };
	},

	unsubscribeLists: function(list){
		requestBody = {EmailAddress: cmBundle.reqEmail};
		unSubscribeEndpoint = "subscribers/#{listID}/unsubscribe.json";
		return { body: JSON.stringify(requestBody), method: "post", rest_url: unSubscribeEndpoint.interpolate({listID: list}) };
	},

	handleUpdateSubscription: function(){
		cmWidget.freshdeskWidget.updateSubscriptionNotifier = true;
		jQuery('#' + this.freshdeskWidget.options.widget_name + ' .emailLists').addClass('loading-center');
		cmWidget.freshdeskWidget.getCampaignsForEmail();
	},

	getActivity: function(list){
		var dfd = jQuery.Deferred();
		activityEndpoint = "subscribers/#{list}/history.json?email=#{email}";
		this.freshdeskWidget.request({
			rest_url: activityEndpoint.interpolate({list: list, email: cmBundle.reqEmail}),
			on_success: function(response){
				cmWidget.activities.push(response.responseJSON)
				dfd.resolve();
			}
		});
		return dfd.promise();
	},

	handleActivities: function(){
		this.subscribedLists = []; unsubscribedLists = []; messages = [];
		activities = {}; campaigns = {}; campaignsTotal = 0; dateSubscribed = [];
		this.contact = {"name": cmBundle.reqName};
		if(this.subLists.length > 0){
			for(i=0; i<this.subLists.length; i++){
				dateSubscribed.push(new Date(this.subLists[i].DateSubscriberAdded.replace(/\-/g,'\/')));
			}
			subDate = _.min(dateSubscribed).toString();
		}
		else{
			subDate = "";
		}
		this.contact.since = subDate;
		cmWidget.freshdeskWidget.renderUser(this.contact);
		if(cmWidget.activities.length  > 0){
			campActivities = cmWidget.activities;
			for(i=0; i<campActivities.length; i++){
				response = campActivities[i];
				for(c=0; c<response.length; c++){
					campaign = response[c];
					if(campaign.Type == "Campaign"){
						cid = campaign.ID;
						campaigns[cid] = {"title": campaign.Name};	
						actions = campaign.Actions;
						if(actions.length > 0){
							for(k=0; k<actions.length; k++){
								if(actions[k].Event != "Unsubscribe"){
									activity = {"type": actions[k].Event, "time": actions[k].Date, "link": actions[k].Detail || "" };
									(activities[cid]) ? activities[cid].push(activity) : activities[cid] = [activity];
								}
								else{
									delete campaigns[cid];	
								}
							}
						}}
						if(_.keys(campaigns).length > 4)
							break;
				}
			}
			for(var camp in campaigns){
				++campaignsTotal;
			}
			if(campaignsTotal == 0)
				cmWidget.freshdeskWidget.handleEmptyCampaigns();	
			else
				cmWidget.freshdeskWidget.renderCampaigns(activities, campaigns);
		}else
			cmWidget.freshdeskWidget.handleEmptyCampaigns();


	},

	handleLists: function(response){
		all_lists = [];
		lists = response.responseJSON;
		for(i=0; i<lists.length; i++){
			all_lists.push({"listId": lists[i].ListID, "name": lists[i].Name});
		}
		return all_lists;	
	},
}
cmWidget = new CampaignMonitorWidget(cmBundle);
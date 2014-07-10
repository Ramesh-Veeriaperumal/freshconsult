var MailChimpWidget = Class.create();
MailChimpWidget.prototype= {
	initialize: function(mailchimpBundle){
		this.ERROR_MAPPER = {"-99": "Unknown Exception", "-98": "Request Timed Out", "-50": "Too many connections. Try again later", "100": "Unknown User", "101": "User disabled", "102": "User does not exist", "104": "Invalid APIKey. Try re-installing the MailChimp addon.", "232": "Contact does not exist", "301": "Campaign stats not available" };
		mailchimpWidget = this;
		mailchimpBundle.integratable_type = "email_marketing";
		mailchimpBundle.app_name = "MailChimp";
		mailchimpBundle.domain = mailchimpBundle.api_endpoint;
		mailchimpBundle.ssl_enabled = "true";
		mailchimpBundle.auth_type = "UAuth";
		mailchimpBundle.username = mailchimpBundle.token;
		mailchimpBundle.url_token_key = "apikey";
		mailchimpBundle.requestForListSub = true;
		mailchimpBundle.requests = {getAllLists: this.getAllLists(), getSubscribedLists: this.getSubscribedLists()};
		this.freshdeskWidget = new Freshdesk.EmailMarketingWidget(mailchimpBundle, this);
	},

	getCampaignsForEmail: function(){
		campaignEmailEndpoint = "1.3/?method=campaignsForEmail&email_address=#{email}";
		return { rest_url: campaignEmailEndpoint.interpolate({email: mailchimpBundle.reqEmail}), on_success: this.getCampaignsForEmailSuccess.bind(this) }
	},

	contactRequest: function(list){
		subscribeEmailEndpoint = "1.3/?method=listSubscribe&email_address=#{email}&id=#{listId}&double_optin=false"
		return { rest_url: subscribeEmailEndpoint.interpolate({listId: list, email: mailchimpBundle.reqEmail}) };
	},

	getCampaignsForEmailSuccess: function(response){
			this.campaignsList = response.responseJSON;
			if(response.responseJSON.code){
				if(response.responseJSON.code == "232")
					this.freshdeskWidget.exportUser();
				else
					this.freshdeskWidget.processFailure(this.fetchErrorMessage(response));
			}
			else{
				if (this.campaignsList.length > 0)
					this.getCampaigns();
				else{
					this.freshdeskWidget.renderUser();
					this.freshdeskWidget.handleEmptyCampaigns();	
				}
			}
	},

	getCampaigns: function(){
		campaignIds = this.campaignsList.join(',');
		campaignEndpoint = "1.3/?method=campaigns&filters[campaign_id]=#{campaigns}";
		this.freshdeskWidget.request({
			rest_url: campaignEndpoint.interpolate({campaigns: campaignIds}) ,
			on_failure: this.processFailure,
			on_success: this.getCampaignsSuccess.bind(this)
		});	
	},

	getCampaignsSuccess: function(response){
		campaigns = {}; 
		campaignsInfo = response.responseJSON.data;
		if(response.responseJSON.code)
			this.freshdeskWidget.processFailure(this.fetchErrorMessage(response));
		else{
			for(i=0; i<campaignsInfo.length; i++){
				id =  campaignsInfo[i].id; title = campaignsInfo[i].title;
				campaigns[id] = {"title": title, "send_time": campaignsInfo[i].send_time};
				if(_.keys(campaigns).length > 4)
					break;
			}
			this.campaigns = campaigns;
			this.getListMemberInfo(campaignsInfo[0].list_id);	
		}
		
	},

	getListMemberInfo: function(lId){
		memberInfoEndpoint = "1.3/?method=listMemberInfo&id=#{listId}&email_address=#{email}";
		this.freshdeskWidget.request({
			rest_url: memberInfoEndpoint.interpolate({listId: lId, email: mailchimpBundle.reqEmail}),
			on_failure: this.processFailure,
			on_success: this.renderMemberInfo.bind(this)
		});	
	},

	getCampaignActivity: function(campaignId){
		this.cid = campaignId;
		campaignActivityEndpoint = "1.3/?method=campaignEmailStatsAIM&email_address=#{email}&cid=#{cid}"
		this.freshdeskWidget.request({
			rest_url: campaignActivityEndpoint.interpolate({cid: campaignId, email: mailchimpBundle.reqEmail}) ,
			on_failure: this.processFailure,
			on_success: this.renderActivitySuccess.bind(this)
		});	
	},

	getAllLists: function(){
		allListsEndpoint = "1.3/?method=lists"
		return { rest_url: allListsEndpoint.interpolate({token: mailchimpBundle.token}) }
	},

	handleLists: function(response){
		all_lists = []
		if(response.responseJSON.code)
			this.freshdeskWidget.processFailure(this.fetchErrorMessage(response));
		else{
			lists = response.responseJSON.data;
				for(i=0; i<lists.length; i++){
					all_lists.push({"listId": lists[i].id, "name": lists[i].name});
				}
			return all_lists;	
		}
	},

	getSubscribedLists: function(){
		listsForEmailEndpoint = "1.3/?method=listsForEmail&email_address=#{email}"
		return { rest_url: listsForEmailEndpoint.interpolate({email: mailchimpBundle.reqEmail}) };
	},

	handleSubscribedLists: function(response){
		return response.responseJSON;
	},

	handleUpdateSubscription: function(){
		mailchimpWidget.freshdeskWidget.getAllLists();
	},

	subscribeLists: function(list){
		subscribeEmailEndpoint = "1.3/?method=listSubscribe&email_address=#{email}&id=#{listId}&double_optin=false"
		return { rest_url: subscribeEmailEndpoint.interpolate({listId: list, email: mailchimpBundle.reqEmail}) };
	},

	unsubscribeLists: function(list){
		unsubscribeEmailEndpoint = "1.3/?method=listUnsubscribe&email_address=#{email}&id=#{listId}&send_goodbye=false"
		return { rest_url: unsubscribeEmailEndpoint.interpolate({listId: list, email: mailchimpBundle.reqEmail}) };
	},

	renderActivitySuccess: function(response){
		activitiesHistory = {};
		if(response.responseJSON.code)
			this.freshdeskWidget.processFailure(this.fetchErrorMessage(response));
		else{
			activities = response.responseJSON.data[0].activity;
				for(i=0; i<activities.length; i++){
					activity = {"type": activities[i].action, "time": activities[i].timestamp, "link": activities[i].url};
					(activitiesHistory[this.cid]) ? activitiesHistory[this.cid].push(activity) : activitiesHistory[this.cid] = [activity];
				}
			this.freshdeskWidget.getCampaignActivity(this.cid, activitiesHistory)	
		}
	},

	renderMemberInfo: function(response){
		member = response.responseJSON.data[0];
		if(member){
			this.contact = {"name": mailchimpBundle.reqName, "since": member.timestamp}
			this.freshdeskWidget.renderUser(this.contact);
			this.freshdeskWidget.renderCampaigns({}, this.campaigns);
		}
	},

	fetchErrorMessage: function(response){
		return	this.ERROR_MAPPER[response.responseJSON.code] || "Unknown error. Please contact Support." 
	}

}
mailchimpWidget = new MailChimpWidget(mailchimpBundle);

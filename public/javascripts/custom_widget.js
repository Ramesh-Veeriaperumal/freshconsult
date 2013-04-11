var Freshdesk = {}
jsLoadPath = document.getElementsByTagName("script")
timeStamp = jsLoadPath[jsLoadPath.length-1].src.split('?')[1]
Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		this.app_name = this.options.app_name || this.app_name || "Integrated Application";
		if(!this.options.widget_name) this.options.widget_name = this.app_name.toLowerCase().replace(' ', '_')+"_widget"
		if(!this.options.username) this.options.username = Cookie.retrieve(this.options.widget_name+"_username");
		if(!this.options.password) this.options.password = Cookie.retrieve(this.options.widget_name+"_password") || 'x'; // 'x' is for API key handling.
		this.callbacks_awaiting_access_token = [];
		this.content_element = $$("#"+this.options.widget_name+" .content")[0];
		this.error_element = $$("#"+this.options.widget_name+" .error")[0];
		this.title_element = $$("#"+this.options.widget_name+" #title")[0];
		if(this.options.title){
			this.title_element.innerHTML = this.options.title;
		}
		this.display();
		this.call_init_requests();
	},
	getUsername: function() {
		return this.options.username;
	},

	login:function(credentials){
		this.options.username = credentials.username.value;
		this.options.password = credentials.password.value;
		if(this.options.username.blank() && this.options.password.blank()) {
			this.alert_failure("Please provide Username and password.");
		} else {
			if (credentials.remember_me.value == "true") {
				Cookie.update(this.options.widget_name + "_username", this.options.username);
				Cookie.update(this.options.widget_name + "_password", this.options.password);
			}
			this.display();
			this.call_init_requests();
		}
	},

	logout:function(){
		Cookie.remove(this.options.widget_name+"_username"); this.options.username=null;
		Cookie.remove(this.options.widget_name+"_password"); this.options.password=null;
		this.display();
	},

	display_login:function(){
		if (this.options.login_html != null) {
			this.content_element.innerHTML = (typeof this.options.login_html == "function") ? this.options.login_html() : this.options.login_html;
		}
	},

	display:function(element){
		element = element || this.content_element;
		var cw = this;
		if(this.options.login_html != null && !(this.options.username && this.options.password)){
			cw.display_login();
		} else {
			if (this.options.application_html){
				element.innerHTML = (typeof this.options.application_html == "function") ? this.options.application_html() : this.options.application_html;
			}
		}
	},

	call_init_requests: function() {
		if(this.options.init_requests){
			var cw=this;
			this.options.init_requests.each(function(reqData){
				if(reqData) cw.request(reqData); 
			});
		}
	},

	request:function(reqData){
		var reqName = reqData;
		if(typeof reqData == "string") {
			reqData = this.options.requests[reqName];
		}
		reqData.domain = this.options.domain;
		reqData.ssl_enabled = this.options.ssl_enabled;
		reqData.accept_type = reqData.accept_type || reqData.content_type;
		reqData.method = reqData.method || "get";
		reqHeader = reqData.reqHeader || {}
		if(this.options.use_server_password) {
			reqData.username = this.options.username;
			reqData.use_server_password = this.options.use_server_password;
			reqData.app_name = this.options.app_name.toLowerCase().replace(' ', '_');
		}
		else if(this.options.auth_type == 'OAuth'){
			if(this.options.url_token_key) {
				if (reqData.resource == null) reqData.resource = reqData.rest_url;
				merge_sym = (reqData.resource.indexOf('?') == -1) ? '?' : '&'
				reqData.rest_url = reqData.resource + merge_sym + this.options.url_token_key + '=' + this.options.oauth_token;
			} else
				
				reqHeader.Authorization = "OAuth " + this.options.oauth_token;
		}
		else if(this.options.auth_type == 'NoAuth'){}
		else if(this.options.auth_type == 'UAuth'){
			if (reqData.resource == null) reqData.resource = reqData.rest_url;
			merge_sym = (reqData.resource.indexOf('?') == -1) ? '?' : '&'
			reqData.rest_url = reqData.resource + merge_sym + this.options.url_token_key + '=' + this.options.username;
		}
		else{
			reqHeader.Authorization = "Basic " + Base64.encode(this.options.username + ":" + this.options.password);
		}
		url = reqData.source_url ? reqData.source_url : "/http_request_proxy/fetch"
		var custom_callbacks = jQuery.extend(false, {}, reqData.custom_callbacks); // onXXX
		reqData.custom_callbacks = null
		var reqHeader_copy = jQuery.extend(false, {}, reqHeader)
		var reqObj=null;
		new Ajax.Request(url, reqObj=jQuery.extend(false, {
		    asynchronous: true,
			parameters:reqData,
			requestHeaders:reqHeader,
			onSuccess:function(evt) {
				this.resource_success(evt, reqName, reqData)
			}.bind(this),
			onFailure:function(evt) {
				this.resource_failure(evt, reqData, reqHeader_copy)
			}.bind(this)
		}, custom_callbacks));
	},

	resource_success:function(evt, reqName, reqData) {
		if(reqData != null && reqData.on_success != null){
			reqData.on_success(evt);
		} else {
			if(this.options.parsers != null && this.options.parsers[reqName] != null) resJ = this.options.parsers[reqName](evt);
			if(this.options.templates != null && this.options.templates[reqName] != null) {
				this.options.application_html = _.template(this.options.templates[reqName], resJ)
				this.options.display();
			}
		}
	},

	resource_failure:function(evt, reqData, reqHeader){
		resJ = evt.responseJSON;
		
		var req_sent_again = false;

		if (evt.status == 401) {
			this.options.username = null;
			this.options.password = null;
			Cookie.remove(this.options.widget_name + "_username");
			Cookie.remove(this.options.widget_name + "_password");
			if (typeof reqData.on_failure != 'undefined' && reqData.on_failure != null) {
				reqData.on_failure(evt);
			} else if (this.options.auth_type == 'OAuth'){
				cw = this;
				req_sent_again = true;						
				this.refresh_access_token(function(){
					if(this.options.oauth_token) {
						this.request(reqData);
					} else {
						this.alert_failure("Problem in connecting to "+this.app_name+". Please try again later.");
						reqData.after_failure(evt);
					}
				}.bind(this), reqHeader);
			} else { this.alert_failure("Given user credentials for "+this.app_name+" are incorrect. Please verify your integration settings and try again."); }
		}
		else if (evt.status == 403) {
			err_msg = (resJ) ? ((resJ[0].message) ? resJ[0].message : evt.statusText) : "Request forbidden."
			this.alert_failure(this.app_name+" declined the request. \n\n " + this.app_name + " returns the following error : " + err_msg);
		}
		else if (evt.status == 502) {
			this.alert_failure(this.app_name+" is not responding.  Please verify the given domain or try again later.");
		}
		else if (evt.status == 504) {
			this.alert_failure("Request timed out. Please try again later.");
		}
		else if (evt.status == 500) {
			// Right now 500 is used for freshdesk internal server error. The below one is special handling for Harvest.  If more apps follows this convention then move it to widget code.
			if (this.app_name == "Harvest") {
				var error = XmlUtil.extractEntities(evt.responseXML,"error");
				if (error.length > 0) {
					err_msg = XmlUtil.getNodeValueStr(error[0], "message");
					alert(this.app_name+" reports the below error: \n\n" + err_msg + "\n\nTry again after correcting the error or fix the error manually.  If you can not do so, contact support.");
					return;
				}
			}
			this.alert_failure("Unknown server error. Please contact support@freshdesk.com.");
		} else if (typeof reqData.on_failure != 'undefined' && reqData.on_failure != null) {
			reqData.on_failure(evt);
		} else if (evt.status == 404){
				if(this.app_name == "Google Calendar"){ /* Event could have been deleted. Blank for now */ }
				else {
					this.alert_failure("Could not fetch data from " + (this.options.domain || this.domain) + "\n\nPlease verify your integration settings and try again.");
				}			
		} else {
				errorStr = evt.responseText;
				this.alert_failure(this.app_name+" reports the below error: \n\n" + errorStr + ".\n\nTry fixing the error or Contact Support.");
		}
		if(!req_sent_again){
			loading_elem = jQuery('div[class^="loading-"]').attr('class');
			if(loading_elem){
				loading_class_elems = loading_elem.split();
				for(i=0; i<loading_class_elems.length; i++){
					if(loading_class_elems[i].startsWith("loading-")){
						jQuery('div[class^="loading-"]').removeClass(loading_class_elems[i]);
					}
				}
			}			
			if(reqData.after_failure) reqData.after_failure(evt);
		}
	},

	alert_failure:function(errorMsg) {
		if (this.error_element == null || this.error_element == "") {
			alert(errorMsg);
		} else {
			jQuery(this.error_element).removeClass('hide').parent().removeClass('loading-fb');
			this.error_element.innerHTML = errorMsg;
		}
		jQuery("#" + this.options.widget_name).removeClass('loading-fb');
	},

	refresh_access_token:function(callback, reqHeader){
		
		cw = this;
		// Retry with new access_token; if we have one
		if(typeof reqHeader != 'undefined' && reqHeader.Authorization){			
			reqHeader = reqHeader.Authorization.split(' ');
			if(reqHeader[1] != this.options.oauth_token && !this.awaiting_access_token)
			{
				if(callback) callback(); 
				return;
			}
		}
		this.options.oauth_token = null;
		this.callbacks_awaiting_access_token.push(callback);
		if(this.awaiting_access_token)	return;
		this.awaiting_access_token = true;
		new Ajax.Request("/integrations/refresh_access_token/"+this.options.app_name.toLowerCase().replace(' ', '_'), {
				asynchronous: true,
				method: "get",
				onSuccess: function(evt){
					resJ = evt.responseJSON;
					this.options.oauth_token = resJ.access_token;
					this.awaiting_access_token = false;
					this.callbacks_awaiting_access_token.each(function(callback){						
						if(callback) callback();
					});
					this.callbacks_awaiting_access_token = [];
				}.bind(this),
				onFailure: function(evt){
					this.options.oauth_token = null;
					this.awaiting_access_token = false;
					this.callbacks_awaiting_access_token.each(function(callback){						
						if(callback) callback();
					});
					this.callbacks_awaiting_access_token = [];
				}.bind(this)
			});
	},


	create_integrated_resource:function(resultCallback) {
		if (this.remote_integratable_id && this.local_integratable_id) {
			reqData = {
				"application_id": this.options.application_id,
				"integrated_resource[remote_integratable_id]": this.remote_integratable_id,
				"integrated_resource[local_integratable_id]": this.local_integratable_id,
				"integrated_resource[local_integratable_type]": this.options.integratable_type
			};
			new Ajax.Request("/integrations/integrated_resources/create", {
				asynchronous: true,
				method: "post",
				parameters: reqData,
				onSuccess: function(evt){
					this.remote_integratable_id = null;
					this.local_integratable_id = null;
					if (resultCallback) 
						resultCallback(evt);
				},
				onFailure: function(evt){
					if (resultCallback)
						resultCallback(evt);
				}
			});
		}
	},

	update_integrated_resource: function(integrated_resource_id, local_integratable_id, remote_integratable_id, resultCallback) {
		if(integrated_resource_id != null && integrated_resource_id != ""){
			reqData = { "integrated_resource[id]": integrated_resource_id };
			if(local_integratable_id) reqData["integrated_resource[local_integratable_id]"] = local_integratable_id;
			if(remote_integratable_id) reqData["integrated_resource[remote_integratable_id]"] = remote_integratable_id;
			
			new Ajax.Request("/integrations/integrated_resources/update",{
		        asynchronous: true,
				method: "put",
				parameters:reqData,
				onSuccess:function(evt) { if(resultCallback) resultCallback(evt);
				},
				onFailure:function(evt){ if(resultCallback) resultCallback(evt);
				}
			});	
		}
		
	},

	delete_integrated_resource:function(integrated_resource_id, resultCallback) {
		if(integrated_resource_id != null && integrated_resource_id != ""){
			reqData = {
			"integrated_resource[id]":integrated_resource_id
			};
			new Ajax.Request("/integrations/integrated_resources/delete",{
        asynchronous: true,
				method: "delete",
				parameters:reqData,
				onSuccess:function(evt) { if(resultCallback) resultCallback(evt);
				},
				onFailure:function(evt){ if(resultCallback) resultCallback(evt);
				}
			});	
		}
		
	},

	prettyDate: function(dateStr){
		var date = new Date(dateStr),
        diff = (((new Date()).getTime() - date.getTime()) / 1000),
        day_diff = Math.floor(diff / 86400);

      // return date for anything greater than a day
      if ( isNaN(day_diff) || day_diff < 0 || day_diff > 0 )
        return date.getDate() + " " + date.toDateString().split(" ")[1];

      return day_diff == 0 && (
          diff < 60 && "just now" ||
          diff < 120 && "a minute ago" ||
          diff < 3600 && Math.floor( diff / 60 ) + " minutes ago" ||
          diff < 7200 && "1 hour ago" ||
          diff < 86400 && Math.floor( diff / 3600 ) + " hours ago") ||
        day_diff == 1 && "Yesterday" ||
        day_diff < 7 && day_diff + " days ago" ||
        day_diff < 31 && Math.ceil( day_diff / 7 ) + " weeks ago";
	}
};

Freshdesk.EmailMarketingWidget = Class.create(Freshdesk.Widget, {
	initialize: function($super, widgetOptions, integratable_impl){
		if(widgetOptions.reqEmail == ""){
			this.alert_failure('Email not available for this requester. Please make sure a valid Email is set for this requester.');
		}else{
			cw = this;
			this.app = widgetOptions.app_name.toLowerCase();
			widgetOptions.parsers = {getUserInfo: this.handleUser.bind(this), getCampaigns: this.handleCampaigns.bind(this), getAllLists: this.handleLists.bind(this), getSubscribedLists: this.handleSubscribedLists.bind(this)};
			widgetOptions = this.updateRequests(widgetOptions);
			widgetOptions.integratable_impl = integratable_impl;
			$super(widgetOptions);
			this.renderPrimary();
			this.mc_subscribe_lists = []; this.mc_unsubscribe_lists = []; cw.title = [];
		}
	},

	renderPrimary: function(){
		jQuery('#' + this.app + "_widget").addClass('loading-center');
		if(this.app == "icontact" || this.app == "constantcontact"){
			this.getUserInfo(); 
		}
		else if(this.app == "mailchimp" || this.app == "campaignmonitor"){
			this.getCampaignsForEmail();
		}
		this.bindClicks();
	},

	bindClicks: function(){
		var obj = this;
		jQuery('#' + this.options.widget_name).on('click','.lists-submit', (function(ev){
			ev.preventDefault(); obj.manageLists();
		}));
		jQuery('#' + this.options.widget_name).on('click', '.contact-submit', (function(ev){
			ev.preventDefault(); obj.addUser();
		}));
		jQuery('#' + this.options.widget_name).on('click', '.newlists-submit', (function(ev){
			ev.preventDefault(); obj.newSubscribe();
		}));
		jQuery('#' + this.app + "_widget").on('click', '.list-tab', (function(ev){
			ev.preventDefault(); obj.mailingLists();
		}));
		jQuery('#' + this.app + "_widget").on('click', '.campaign-tab', (function(ev){
			ev.preventDefault(); obj.campaignActivity();
		}));
	},

	updateRequests: function(options){
		for(key in options.requests){
			options.requests[key].on_failure = this.handleFailure.bind(this);
		}
		return options;
	},

	getUserInfo: function(){
		this.request("getUserInfo");
	},

	getCampaigns: function(id){
		this.options.requests["getCampaigns"].rest_url = this.options.requests["getCampaigns"].rest_url.interpolate({contactId: id});
		this.request("getCampaigns");
	},

	getCampaignsForEmail: function(){
		campaignEmail_req = this.options.integratable_impl.getCampaignsForEmail();
		if(campaignEmail_req) {
			this.request(campaignEmail_req);
		}
	},

	getAllLists: function(){
		this.request("getAllLists");
	},

	getSubscribedLists: function(){
		if(this.options.requestForListSub == true){
			sublists_req = this.options.integratable_impl.getSubscribedLists();
			if(sublists_req) {
				sublists_req.on_success = this.handleSubscribedLists.bind(this);
				sublists_req.on_failure = this.handleFailure.bind(this);
				this.request(sublists_req);
			}
		}else{
			this.options.requestForListSub = false;
			this.lists = this.options.integratable_impl.getSubscribedLists();
			this.handleSubscribedLists();
		}
	},

	addUser: function () {
		jQuery('#' + this.options.widget_name + ' .lists-load').siblings().hide();
		jQuery('#' + this.options.widget_name + ' .lists-load').prepend("<hr/>").slideDown("slow");
		if(this.app == "icontact") {
			this.options.integratable_impl.addContact();
		}
		else{
			this.getAllLists();
			this.exportFlag = true;
		}
	},

	exportUser: function(){
		var obj = this; var export_contact = {};
		this.renderTemplate(_.template(this.Export, {name: this.options.reqName, email: this.options.reqEmail, appname: this.options.app_name}));
		
		jQuery('#' + this.options.widget_name).removeClass('loading-center');
		this.renderUser(export_contact);
	},

	newSubscribe: function(){
		var subscribed = []; this.mc_subscribe_lists = []; this.mc_unsubscribe_lists = [];
		if(jQuery('#' + this.options.widget_name + ' .lists input:checked').length == 0){
			this.processFailure("Please select a mailing list to proceed");
		}else{
			jQuery(this.error_element).addClass('hide');
			var obj = this;
			jQuery('#' + this.options.widget_name + ' .lists input:checked').each(function() {
			if(obj.mc_subscribe_lists.indexOf($(this).id) < 0)
		  	subscribed.push($(this).id);
			});
			this.exportFlag = false;
			jQuery('#' + this.options.widget_name + ' .lists-load').hide();
			jQuery('#' + this.options.widget_name).addClass('loading-center');
			
			if(this.app == "campaignmonitor" || this.app == "mailchimp"){
				this.addContact(subscribed);
			}else	
			this.options.integratable_impl.addContact(subscribed);
		}
	},

	addContact: function(lists){
		requestBody = {EmailAddress: this.options.reqEmail};
		dfd_arr = [];
		for(i=0; i<lists.length; i++){
			dfd_arr.push(this.contactRequest(lists[i]));
		}
		jQuery.when.apply(null, dfd_arr).then(this.handleAddContact.bind(this));
	},

	contactRequest: function(list){
		var dfd = jQuery.Deferred();
		this.contactReqFailure = [];
		subReq = this.options.integratable_impl.contactRequest(list);
		if(subReq){
			subReq.on_success = function(response){
				if(response.responseJSON.error)
					this.contactReqFailure.push(response.responseJSON.error);		
				dfd.resolve();
			}.bind(this);
			subReq.on_failure = function(response){
				if(response.responseJSON.error)
					this.contactReqFailure.push(response.responseJSON.error);
				else
					this.contactReqFailure.push(response.responseText);
				dfd.resolve();
			}.bind(this);
			this.request(subReq);
		}
		return dfd.promise();
	},

	handleAddContact: function(){
		if(this.contactReqFailure.length > 0){
			this.processFailure("Unable to add the contact to " + this.options.app_name);
			this.exportUser();
		}
		else{
			this.getCampaignsForEmail();
		}
	},


	handleUser: function(response){
		contact = this.options.integratable_impl.handleUser(response);
		this.renderUser(contact);
		this.getCampaigns(contact.id);	
	},

	handleCampaigns: function(response){
		var campaignActivities = this.options.integratable_impl.handleCampaigns(response);
		var campaigns = campaignActivities.campaigns; 
		var activities = campaignActivities.activities;
		this.renderCampaigns(activities, campaigns);
	},

	handleEmptyCampaigns: function(){
		this.campaignTmpl = _.template(this.EmptyData, {type: "campaign history", contact: this.options.reqName});
		this.renderModal();
		if(this.updateSubscriptionNotifier == true){
			this.listsTmpl = null;
			this.mailingLists();
		}
	},

	handleEmptyLists: function(){
		this.listsTmpl = _.template(this.EmptyData, {type: "mailing lists", contact: "the linked " + this.options.app_name + " account"});
		jQuery('#' + this.options.widget_name + ' .emailLists').html(this.listsTmpl);
	},

	handleSubscribedLists: function(response){
		var obj = this; this.mc_subscribe_lists = []; this.mc_unsubscribe_lists = [];
		if(this.options.requestForListSub == false){
			lists = this.lists;
		}
		else{
			lists = this.options.integratable_impl.handleSubscribedLists(response);
		}
		for(var i=0; i<lists.length; i++){
			jQuery('#'+lists[i]).attr('checked', true);
			this.mc_subscribe_lists.push(lists[i]);
		}
		jQuery('#' + this.options.widget_name + ' .lists input:unchecked').each(function() {
		  obj.mc_unsubscribe_lists.push($(this).id);
		});
		this.listsTmpl = jQuery('#' + this.options.widget_name + ' .lists-load')[0];
		jQuery('#' + this.options.widget_name + ' .lists-load').removeClass('hide');
		jQuery('#' + this.options.widget_name + ' .emailLists').removeClass('loading-center');
	},

	handleLists: function(response){
		var all_lists = ""; var obj = this;
		var lists = this.options.integratable_impl.handleLists(response);
		if(lists.length > 0){
			for(i=0; i<lists.length; i++){
				all_lists += _.template(this.UserLists, {listId: lists[i].listId, listTitle: lists[i].name});
			}
			if(this.exportFlag){
				this.renderTemplate(_.template(this.NewLists, {lists: all_lists}), jQuery('#' + this.options.widget_name + ' .lists-load')[0]);
				jQuery('#' + this.options.widget_name + ' .lists-load').removeClass('loading-center').prepend("<hr/>");
			}
			else{
				this.renderTemplate(_.template(this.MailingLists, {lists: all_lists}), jQuery('#' + this.options.widget_name + ' .emailLists')[0]);
				this.getSubscribedLists();
			}
		}
		else{
			this.handleEmptyLists();
		}
	},

	bindShowActivity: function(activities){
		var email_marketing = this;
		jQuery('#show-activity-'+this.app).die();
		jQuery('#show-activity-'+this.app).live('click', function(ev){
			ev.preventDefault();
			cid = jQuery(this).attr("class").split(" ")[1];
			if(jQuery('#user-campaign-' + cid).is(":visible") == false){
				jQuery('#user-campaign-' + cid).slideDown();
				if(email_marketing.app == "mailchimp")
					email_marketing.options.integratable_impl.getCampaignActivity((jQuery(this).attr("class")).split(" ")[1]);
				else{
					if(_.keys(activities[cid]).length == 0)
						activities[cid] = [{"type": "", "time": "No campaign activity found for this campaign"}]
					email_marketing.getCampaignActivity((jQuery(this).attr("class")).split(" ")[1], activities);
				}
					
				jQuery('#user-campaign-' + cid).removeClass('hide');
				jQuery('.'+cid).children().css('background-color', '#DDD');
			}else{
				jQuery('#user-campaign-' + cid).slideUp();
				jQuery('.'+cid).children().css('background-color', '');
			}
		})
	},

	formatDate: function(dateString){
		send_time = dateString.replace(/[T|Z]/g, ' ').split(/\s/);
		activity_time = (send_time[0].replace(/\-/g,'\/') + " " + send_time[1]);
		return new Date(activity_time).strftime("%a, %d %b %Y, %r");
	},

		getCampaignActivity: function(campaignId, activities){
		var activity = "", activities_time = "";
		if(this.campaigns[campaignId].send_time){
			activity = _.template(this.CampaignActivity, {action: "Sent", action_time: this.formatDate(this.campaigns[campaignId].send_time), action_url: ""});
		}
		for(key in activities){
			if(key == campaignId){
				for(i=0; i<activities[key].length; i++){
					if(this.app != "constantcontact"){
						if(activities[key][i].time && activities[key][i].time != "") 
							if(activities[key][i].type != "")
								activities_time = this.formatDate(activities[key][i].time);
							else
								activities_time = activities[key][i].time;
					}
					else{
						activities_time = activities[key][i].time;
					}
					activity += _.template(this.CampaignActivity, {action: activities[key][i].type, action_time: activities_time, action_url: activities[key][i].link || ""});
				}
			}
		}
		j = '#user-campaign-' + campaignId
		this.renderTemplate(activity, jQuery(j + ' .campaign-details')[0]);
		jQuery(j + ' .campaign-details').removeClass('hide');
		jQuery(j).removeClass('loading-fb');
	},

	manageLists: function(){
		var subscribed = new Array(); var unsubscribed = new Array(); var obj = this;
		jQuery('#' + this.options.widget_name + ' .lists input:checked').each(function() {
			if(obj.mc_subscribe_lists.indexOf($(this).id) < 0)
		  	subscribed.push($(this).id);
		});
		jQuery('#' + this.options.widget_name + ' .lists input:unchecked').each(function() {
		   if(obj.mc_unsubscribe_lists.indexOf($(this).id) < 0)
		  	unsubscribed.push($(this).id);
		});
		this.mc_subscribe_lists = []; this.mc_unsubscribe_lists = [];
		jQuery('#' + this.options.widget_name + ' .lists input:checked').each(function() {
		  obj.mc_subscribe_lists.push($(this).id);
		});
		jQuery('#' + this.options.widget_name + ' .lists input:unchecked').each(function() {
		  obj.mc_unsubscribe_lists.push($(this).id);
		});
		if (subscribed.length == 0 && unsubscribed.length == 0){
			if (jQuery('#' + this.options.widget_name + ' .lists input:checked').length > 0)
				this.processFailure("The selected mailing lists are already subscribed. Please select a new mailing list to proceed");	
			else
				this.processFailure("Please select a mailing list to proceed");
		}
		else{
			if(this.app == "campaignmonitor" || this.app == "mailchimp")
				this.updateSubscription(subscribed, unsubscribed);
			else
				this.options.integratable_impl.updateSubscription(subscribed, unsubscribed);	
		}
		
	},

	updateSubscription: function(subscribed, unsubscribed){
		var updateCalls = []; this.ErrorMessages = [];
		for(i=0; i<subscribed.length; i++){
			updateCalls.push(this.subscribeLists(subscribed[i]));
		}
		for(i=0; i<unsubscribed.length; i++){
			updateCalls.push(this.unsubscribeLists(unsubscribed[i]));
		}
		jQuery.when.apply(null, updateCalls).then(this.handleUpdateSubscription.bind(this));
		jQuery('#' + this.options.widget_name + ' .lists-load').hide();
		jQuery('#' + this.options.widget_name + ' .emailLists').addClass('loading-center');
	},

	handleUpdateSubscription: function(){
		this.listsTmpl = null;
		if(this.ErrorMessages.length > 0){
			this.processFailure(this.ErrorMessages[(this.ErrorMessages.length-1)]);
		}
		this.options.integratable_impl.handleUpdateSubscription();
		
	},

	subscribeLists: function(list){
		var dfd = jQuery.Deferred();
		addSubRequest = this.options.integratable_impl.subscribeLists(list);
		if(addSubRequest){
			addSubRequest.on_success = function(response){
				if(response.responseJSON){
					if(response.responseJSON.error || response.responseJSON.Message)
					this.ErrorMessages.push(response.responseJSON.error || response.responseJSON.Message);			
				}
				dfd.resolve();
			}.bind(this);
			addSubRequest.on_failure = function(response){
				if(response.responseJSON)
					this.ErrorMessages.push(response.responseJSON.error || response.responseJSON.Message)
				dfd.resolve();
			}.bind(this);
			this.request(addSubRequest);
		}
		return dfd.promise();	
	},

	unsubscribeLists: function(list){
		var dfd = jQuery.Deferred();
		addUnSubRequest = this.options.integratable_impl.unsubscribeLists(list);
		if(addUnSubRequest){
			addUnSubRequest.on_success = function(response){
				if(response.responseJSON){
					if(response.responseJSON.error || response.responseJSON.Message)
						this.ErrorMessages.push(response.responseJSON.error || response.responseJSON.Message);		
				}
				dfd.resolve();
			}.bind(this);
			addUnSubRequest.on_failure = function(response){
				if(response.responseJSON)
					this.ErrorMessages.push(response.responseJSON.error || response.responseJSON.Message)
				dfd.resolve();
			}.bind(this);
			this.request(addUnSubRequest);
		}
		return dfd.promise();	
	},

	campaignActivity: function(){
		var j = '#' + this.options.widget_name
		jQuery(j + ' .emailCampaigns').removeClass('hide');
		jQuery(j + ' .emailLists').addClass('hide');
		jQuery(j + ' .emailCampaigns').html(this.campaignTmpl);
		jQuery(j + ' .list-tab').removeClass('active');
		jQuery(j + ' .campaign-tab').addClass('active');
	},

	mailingLists: function(){
		var j = '#' + this.options.widget_name
		jQuery(j + ' .emailCampaigns').addClass('hide');
		jQuery(j + ' .emailLists').removeClass('hide');
		jQuery(j + ' .list-tab').addClass('active');
		jQuery(j + ' .campaign-tab').removeClass('active');
		if(this.listsTmpl){
			jQuery(j + ' .emailLists').html(this.listsTmpl);
			jQuery(j + ' .lists-load').show();
			jQuery(j + ' .emailLists').removeClass('loading-center');
		}
		else{
			this.getAllLists();	
		}
			
	},

	renderModal: function(){
		var ecw = this;
		jQuery('#' + this.app + "_widget").removeClass('loading-center');
		this.renderTemplate(_.template(this.Parent, {campaigns: this.campaignTmpl}));
	},

	renderUser: function(contact){
		contact = contact || {};
		contact.name = this.options.reqName;
		title = _.template(this.Title, {contact: contact, app: this.app});
		if (jQuery('#' + this.options.widget_name).dialog( "isOpen" ) == true)
			jQuery('#' + this.options.widget_name).dialog("option", "title", title)
		cw.title[this.app] = title;
	},

	renderCampaigns: function(activities, campaigns){
		this.campaigns = campaigns;
		this.campaignTmpl = _.template(this.Campaigns, {campaigns: campaigns, app: this.app});
		this.renderModal();
		this.bindShowActivity(activities);
		if(this.updateSubscriptionNotifier == true){
			this.listsTmpl = null;
			this.mailingLists();
		}
	},

	addUserFailure: function(){
		error = this.options.integratable_impl.addUserFailure(response);
		if(error == true){
			errorMessage = "Unable to add the contact to " + this.options.app_name;
			this.processFailure(errorMessage);	
		}else{
			jQuery('#' + this.options.widget_name).removeClass('loading-center');	
		}
	},

	handleFailure:function(response) {
		errorMessage = this.options.integratable_impl.processFailure(response);
		this.processFailure(errorMessage || "Unknown server error");
	},

	processFailure: function(msg){
		var obj = this;
		this.alert_failure(this.options.app_name + " reports the following error : " + msg);
		jQuery(obj.error_element).slideDown('slow');
		jQuery('#' + this.app + "_widget").removeClass('loading-center');
		setTimeout(function(){
			jQuery(obj.error_element).slideUp('slow');
		}, 8000);
	},

	renderTemplate: function(template, element){
		this.options.application_html = template;
		this.display(element);
	},

	Title: '<div class="email_marketing">'+
						'<div class="contact_title">'+
							'<div class="<%=app%>-modal-logo"> <h3 class="fname"><%=contact.name%></h3></div><div class="cust-added"><%= (contact.since && contact.since != "") ? ("Customer since " + (new Date(contact.since.replace(/\-/g,"\/")).strftime("%a, %d %b %Y"))) : "" %></div>'+
						'</div>'+
					'</div>',

	Parent: '<div class="parent-container">'+
							'<div class="email_title"></div>'+
								'<div class="parent-tmpl">'+
									'<div class="modal-tabs">'+
										'<ul class="tabs parent-tabs">'+
											'<li class="active campaign-tab"><a href="#">Campaigns</a></li>'+
											'<li class="list-tab"><a href="#">MailingLists</a></li>'+
										'</ul>'+
									'</div>'+
									'<div class="emailCampaigns"><%=campaigns%></div>'+
									'<div class="hide loading-center emailLists"></div>'+
								'</div>'+
						'</div>',

	Export: '<hr/>'+
					'<div class="export-user">'+
						'<span><%=name%>&lt;<%=email%>&gt; cannot be found in <%=appname%></span>'+
						'<div class="contact-submit"><input type="submit" class="uiButton contact-add" value="Subscribe" /></div>'+
					'</div>'+
					'<div class="lists-load loading-center hide"></div>',


	NewLists: '<div class="mailing-msg"><b>Choose from the below mailing lists to add the contact and click Save</b></div>'+
						'<div class="listsExportAll"><input type="submit" class="uiButton newlists-submit"  value="Save"></div>' +
						'<div class="all-lists"><div class="lists threecol-form"><%=lists%></div></div>',


	Campaigns: '<div class="campaigns">'+
							'<div class="campaigns-list">'+
								'<% var keys = [];'+
										'if(app == "icontact"){'+
											'keys = _.keys(campaigns).reverse();'+
									    'for(i=0; i<keys.length; i++){ %>'+
								    		'<div id="show-activity-<%=app%>" class="activity-toggle <%=keys[i]%>"> <div class="campaign-activity campaign-image"><%=campaigns[keys[i]].title%></div></div>'+
												'<div id="user-campaign-<%=keys[i]%>" class="hide loading-fb">'+
													'<div class="activities">'+
													'<div class="campaign-details hide"></div>'+
												'</div>'+
											'</div>'+
									    '<%}}else{'+
										 'for(key in campaigns){%><div id="show-activity-<%=app%>" class="activity-toggle <%=key%>"> <div class="campaign-activity campaign-image"><%=campaigns[key].title%></div></div>'+
												'<div id="user-campaign-<%=key%>" class="hide loading-fb">'+
													'<div class="activities">'+
													'<div class="campaign-details hide"></div>'+
												'</div>'+
											'</div><%}}%>'+								
							'</div>'+
						'</div>',

	CampaignActivity: '<div class="activity"><div class="action_type"> <span class="action"> <%=action%> </span></div><span class="action-time"><%=action_time%></span><span class="action-url"><a href="<%=action_url%>" target="_blank"><%=action_url%></a></span> </div>',

	MailingLists: '<div class="mailing-lists">'+
										'<div class="lists-load hide">'+
											'<div class="mailing-msg"><b>Subscribe/Unsubscribe mailing lists below and click Save </b></div>'+
											'<div class="listsExportAll"><input type="submit" class="uiButton lists-submit"  value="Save"></div>' +
											'<div class="all-lists"><div class="lists threecol-form"><%=lists%></div></div>'+
										'</div>'+
									'</div>',

	UserLists: '<div class="item"><label><input type="checkbox" id="<%=listId%>"/><div><%=listTitle%></div></label></div>',

	EmptyData: 	'<div class="empty-response">'+
								'<span>No <%=type%> found for <%=contact%></span>'+
							'</div>'
});

Freshdesk.CRMWidget = Class.create(Freshdesk.Widget, {
	initialize:function($super, widgetOptions, integratable_impl) {
		if(widgetOptions.domain) {
			if(widgetOptions.reqEmail == ""){
				$super(widgetOptions);
				this.alert_failure('Email not available for this requester. A valid Email is required to fetch the contact from '+this.options.app_name);
			} else {
				widgetOptions.integratable_impl = integratable_impl;
				var cnt_req = integratable_impl.get_contact_request();
				if(cnt_req) {
					if(cnt_req.length == undefined) cnt_req = [cnt_req]
					for(var i=0;i<cnt_req.length;i++) {
						cnt_req[i].on_success = this.handleContactSuccess.bind(this);
						if (widgetOptions.auth_type != 'OAuth' && integratable_impl.processFailure)
							cnt_req[i].on_failure = this.handleFailure.bind(this);
					}
					this.contacts = [];
					widgetOptions.init_requests = cnt_req;
				}
				$super(widgetOptions); // This will call the initialize method of Freshdesk.Widget.
			}
		} else {
			$super(widgetOptions);
			this.alert_failure('Domain name not configured. Try reinstalling '+this.options.app_name);
		}
	},

	handleFailure:function(response) {
		this.options.integratable_impl.processFailure(response, this);
	},

	handleContactSuccess:function(response){
		resJson = response.responseJSON;
		if(resJson == null)
			resJson = JSON.parse(response.responseText);
		if(this.contacts = this.contacts.concat(this.options.integratable_impl.parse_contact(resJson, response))) {
			if ( this.contacts.length > 0) {
				if(this.contacts.length == 1){
					this.renderContactWidget(this.contacts[0]);
					jQuery('#search-back').hide();
				} else {
					this.renderSearchResults();
				}
			} else {
				this.renderContactNa();
			}
		}
		jQuery("#"+this.options.widget_name).removeClass('loading-fb');
	},

	renderSearchResults:function(){
		var crmResults="";
		for(var i=0; i<this.contacts.length; i++){
			crmResults += '<a class="multiple-contacts" href="#" data-contact="' + i + '">'+this.contacts[i].name+'</a><br/>';
		}
		var results_number = {resLength: this.contacts.length, requester: this.options.reqEmail, resultsData: crmResults};
		this.renderSearchResultsWidget(results_number);
		var obj = this;
		jQuery('#' + this.options.widget_name).on('click','.multiple-contacts', (function(ev){
			ev.preventDefault();
			obj.renderContactWidget(obj.contacts[jQuery(this).data('contact')]);
		}));
	},

	renderContactWidget:function(eval_params){
		var cw = this;
		eval_params.app_name = this.options.app_name;
		eval_params.widget_name = this.options.widget_name;
		eval_params.type = eval_params.type?eval_params.type:"" ; // Required
		eval_params.department = eval_params.department?eval_params.department:null;
		eval_params.url = eval_params.url?eval_params.url:"#";
		eval_params.address_type_span = eval_params.address_type_span || " ";
		this.options.application_html = function(){ return _.template(cw.VIEW_CONTACT, eval_params);	} 
		this.display();
		var obj = this;
		jQuery('#' + this.options.widget_name).on('click','#search-back', (function(ev){
			ev.preventDefault();
			obj.renderSearchResults();
		}));
	},

	renderSearchResultsWidget:function(results_number){
		var cw=this;
		results_number.widget_name = this.options.widget_name;
		this.options.application_html = function(){ return _.template(cw.CONTACT_SEARCH_RESULTS, results_number);} 
		this.display();
	},

	renderContactNa:function(){
		var cw=this;
		cw.options.url = cw.options.url || "#";
		this.options.application_html = function(){ return _.template(cw.CONTACT_NA, cw.options);} 
		this.display();
	},

	VIEW_CONTACT:
			'<span class="contact-type <%=(type ? "" : "hide")%>"><%=(type || "")%></span>' +
			'<div class="title <%=widget_name%>_bg">' +
				'<div class="name">' +
					'<div id="contact-name" class="contact-name"><a title="<%=name%>" target="_blank" href="<%=url%>"><%=name%></a></div>' +
				    '<div id="contact-desig"><%=(designation ? designation : ( company ? "Works" : "" ))%>' +
					    '<span class="<%=(company ? "dummy" : "hide")%>"> at ' +
					    	'<a target="_blank" href="<%=(company_url || "#")%>"><%=(company || "")%></a>' + 
				    	'</span>' + 
				    '</div>'+
			    '</div>' + 
		    '</div>' + 
		    '<div class="field">' +
		    	'<div id="crm-contact">' +
				    '<label>Address</label>' +
				    '<span id="contact-address"><%=address%><%=address_type_span%></span>' +
			    '</div>'+	
		    '</div>'+	
		    '<div class="field">' +
		    	'<div  id="crm-phone">' +
				    '<label>Phone</label>' +
				    '<span id="contact-phone"><%=phone%></span>'+
			    '</div>' +
		    '</div>' +
		    '<div class="field">' +
				'<div id="crm-mobile">' +
				    '<label>Mobile</label>' +
				    '<span id="contact-mobile"><%=mobile%></span>'+
				'</div>' +
			'</div>' +
		    '<div class="field <%=((department)? "" : "hide") %>">' +
		    	'<div  id="crm-dept">' +
				    '<label>Dept.</label>' +
				    '<span id="contact-dept"><%=(department || "")%></span>' +
			    '</div>' +	
		    '</div>' +
		    '<div class="field bottom_div">' +
		    '</div>' +
			'<div class="external_link"><a id="search-back" href="#"> &laquo; Back </a><a target="_blank" id="crm-view" href="<%=url%>">View <span id="crm-contact-type"></span> on <%=app_name%></a></div>',

	CONTACT_SEARCH_RESULTS:
		'<div class="title <%=widget_name%>_bg">' +
			'<div id="number-returned" class="name"> <%=resLength%> results returned for <%=requester%> </div>'+
			'<div id="search-results"><%=resultsData%></div>'+
		'</div>',

	CONTACT_NA:
		'<div class="title contact-na <%=widget_name%>_bg">' +
			'<div class="name"  id="contact-na">Cannot find <%=reqName%> in <%=app_name%></div>'+
		'</div>'
});

var UIUtil = {

	constructDropDown:function(data, type, dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm, keepOldEntries) {
		foundEntity = "";
		dropDownBox = $(dropDownBoxId);
		if (!keepOldEntries) dropDownBox.innerHTML = "";
		if(type == "xml"){
			parser = XmlUtil;
		} else if(type == "hash"){
			parser = HashUtil;
		} else {
			parser = JsonUtil; 
		}

		var entitiesArray = parser.extractEntities(data, entityName);
		for(var i=0;i<entitiesArray.length;i++) {
			if (filterBy != null && filterBy != '') {
				matched = true;
				for (var filterKey in filterBy) {
					filterValue = filterBy[filterKey];
					if(!this.isMatched(entitiesArray[i], filterKey, filterValue)) {
						matched = false;
						break;
					}
				}
				if (!matched) continue;
			}

			var newEntityOption = new Element("option");
			entityIdValue = parser.getNodeValueStr(entitiesArray[i], entityId);
			entityEmailValue = parser.getNodeValueStr(entitiesArray[i], "email");
			if (searchTerm != null && searchTerm != '') {
				if (entityEmailValue == searchTerm) {
					foundEntity = entitiesArray[i];
					newEntityOption.selected = true;
				} else if (entityIdValue == searchTerm) {
					foundEntity = entitiesArray[i];
					newEntityOption.selected = true;
				}
			}
			dispName = ""
			for(var d=0;d<dispNames.length;d++) {
				if (dispNames[d] == ' ' || dispNames[d] == '(' || dispNames[d] == ')' || dispNames[d] == '-') {
					dispName += dispNames[d];
				} else {
					dispName += parser.getNodeValueStr(entitiesArray[i], dispNames[d]);
				}
			}
			if (dispName.length < 2) dispName = entityEmailValue;

			if (entityIdValue && dispName) {
				newEntityOption.value = entityIdValue;
				newEntityOption.innerHTML = dispName;
				dropDownBox.appendChild(newEntityOption);
			}
			if (foundEntity == "") {
				foundEntity = entitiesArray[i];
				newEntityOption.selected = true;
			}
		}
		return foundEntity;
	},

	isMatched: function(dataNode, filterKey, filterValue) {
		keys = filterKey.split(',');
		if(keys.length>1) {
			first_level_nodes = parser.extractEntities(dataNode, keys[0]);
			for(var i=0;i<first_level_nodes.length;i++) {
				actualVal = parser.getNodeValueStr(first_level_nodes[i], keys[1]);
				if(actualVal == filterValue) return true;
			}
			return false;
		} else {
			actualVal = parser.getNodeValueStr(dataNode, filterKey);
			return actualVal == filterValue;
		}
	},

	addDropdownEntry: function(dropDownBoxId, value, name, addItFirst) {
		projectDropDownBox = $(dropDownBoxId);
		var newEntityOption = new Element("option");
		newEntityOption.value = value;
		newEntityOption.innerHTML = name;
		if(addItFirst)
			projectDropDownBox.insertBefore(newEntityOption, projectDropDownBox.childNodes[0]);
		else
			projectDropDownBox.appendChild(newEntityOption);
	},

	chooseDropdownEntry: function(dropDownBoxId, searchValue) {
		projectDropDownBoxOptions = $(dropDownBoxId).options;
		var len = projectDropDownBoxOptions.length;
		for (var i = 0; i < len; i++) {
			if(projectDropDownBoxOptions[i].value == searchValue) {
				projectDropDownBoxOptions[i].selected = true;
				break;
			} 
		}
	},

	sortDropdown: function(dropDownBoxId) {
		jQuery("#"+dropDownBoxId).html(jQuery("#"+dropDownBoxId+" option").sort(function (a, b) {
				a = a.text.toLowerCase();
				b = b.text.toLowerCase();
				return a == b ? 0 : a < b ? -1 : 1
		}))
	},

	hideLoading: function(integrationName,fieldName,context) {
		jQuery("#" + integrationName + context + '-' + fieldName).removeClass('hide');
		jQuery("#" + integrationName + "-" + fieldName + "-spinner").addClass('hide');

		var parent_form = jQuery("#" + integrationName + context + '-' + fieldName).parentsUntil('form').siblings().andSelf();
		
		if ( parent_form.find('.loading-fb.hide').length == parent_form.find('.loading-fb').length) {
			//All the loading are hidden
			var submit_button = parent_form.filter('.uiButton');
			submit_button.prop('disabled',!submit_button.prop('disabled'));
		}
	},

	showLoading: function(integrationName,fieldName,context) {
		jQuery("#" + integrationName + context + '-' + fieldName).addClass('hide');
		
		jQuery("#" + integrationName + "-" + fieldName + "-spinner").removeClass('hide');
	}
}

var CustomWidget =  {
	include_js: function(jslocation) {
		widget_script = document.createElement('script');
		widget_script.type = 'text/javascript';
		widget_script.src = jslocation+"?"+timeStamp;
		document.getElementsByTagName('head')[0].appendChild(widget_script);
	}
};
CustomWidget.include_js("/javascripts/base64.js");
CustomWidget.include_js("/javascripts/frameworks/underscore-min.js");
CustomWidget.include_js("/javascripts/strftime-min.js");

var XmlUtil = {
	extractEntities:function(resStr, lookupTag){
		return resStr.getElementsByTagName(lookupTag)||new Array();
	},

	getNodeValue:function(dataNode, lookupTag){
		if(dataNode == '') return;
		if(lookupTag instanceof Array) {
			var element = dataNode.getElementsByTagName(lookupTag[0]);
			if(element == null || element.length == 0) return null;
			dataNode = element[0]
			lookupTag = lookupTag[1]
		}
		var element = dataNode.getElementsByTagName(lookupTag);
		if(element == null || element.length == 0) return null;
		childNode = element[0].childNodes[0]
		if(childNode == null) return"";
		return childNode.nodeValue;
	},

	getNodeValueStr:function(dataNode, nodeName){
		return this.getNodeValue(dataNode, nodeName) || "";
	},

	getNodeAttrValue:function(dataNode, lookupTag, attrName){
		var element = dataNode.getElementsByTagName(lookupTag);
		if(element==null || element.length==0){
			return null;
		}
		return element[0].getAttribute(attrName) || null;
	},
	
	loadXMLString: function(xmlString) 
	{
	if (window.DOMParser)
	  {
	  parser=new DOMParser();
	  xmlDoc=parser.parseFromString(xmlString,"text/xml");
	  }
	else // Internet Explorer
	  {
	  xmlDoc=new ActiveXObject("Microsoft.XMLDOM");
	  xmlDoc.async=false;
	  xmlDoc.loadXML(txt); 
	  }
	return xmlDoc;
	}
}

var JsonUtil = {
	extractEntities:function(resStr, lookupTag){
		if(resStr instanceof Array)
			return resStr;
		else if(resStr instanceof Object)
		{
			var result = resStr[lookupTag] || Array();
			return result;	
		}
		
	},
	getNodeValue:function(dataNode, lookupTag){
		if(dataNode == '') return;
		var element = dataNode[lookupTag];
		if(element==null || element.length==0){
			return null;
		}
		return element;
	},

	getNodeValueStr:function(dataNode, nodeName){
		return this.getNodeValue(dataNode, nodeName) || "";
	},

	getMultiNodeValue:function(data, dataNodes){
		var innerJson;
		var innerValue;
		var jsonValue = data;
		var nodeArray = dataNodes.split(".");
		if(nodeArray.length > 1){
			for(var i=0; i<(nodeArray.length - 1); i++){
				innerJson = JsonUtil.extractEntities(jsonValue, nodeArray[i]);
				jsonValue = innerJson;
			}
		innerValue = JsonUtil.getNodeValueStr(jsonValue, nodeArray[nodeArray.length-1]);
		}
		return innerValue;
	}

}

var HashUtil = {
	extractEntities:function(hash, lookupKey){
		return hash[lookupKey] || new Array();
	},

	getNodeValue:function(dataNode, lookupKey){
		if(dataNode == '') return;
		var element = dataNode[lookupKey];
		if(element==null || element.length==0){
			return null;
		}
		return element;
	},

	getNodeValueStr:function(dataNode, lookupKey){
		return this.getNodeValue(dataNode, lookupKey) || "";
	}
}

var Cookie=Class.create({});
Cookie.update = function(cookieId, value, expireDays){
	var expireString="";
	if(expireDate!==undefined){
		var expireDate=new Date();
		expireDate.setTime((24*60*60*1000*parseFloat(expireDays)) + expireDate.getTime());
		expireString="; expires="+expireDate.toGMTString();
	}
	return(document.cookie=escape(cookieId)+"="+escape(value||"") + expireString + "; path=/");
};

Cookie.retrieve = function(cookieId){
	var cookie=document.cookie.match(new RegExp("(^|;)\\s*"+escape(cookieId)+"=([^;\\s]*)"));
	return(cookie?unescape(cookie[2]):null);
};

Cookie.remove = function(cookieId){
	var cookie = Cookie.retrieve(cookieId)||true;
	Cookie.update(cookieId, "", -1);
	return cookie;
};

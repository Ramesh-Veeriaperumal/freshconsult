var Freshdesk = {}
timeStamp = cloudfront_version;
Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		(this.options.auth_type == 'OAuth') ? this.options.refresh_count = 0 : null;
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
		this.access_token_renewal_url = widgetOptions.is_customer ? "/support/user_credentials/refresh_access_token/" : "/integrations/refresh_access_token/";
		this.http_proxy_url = widgetOptions.is_customer ? "/support/http_request_proxy/fetch" : "/http_request_proxy/fetch";
		this.initializeAjaxQueue();
		this.call_init_requests();
	},
	getUsername: function() {
		return this.options.username;
	},

	initializeAjaxQueue:function(){
		this.ajax_queue = {};
		this.ajax_queue[this.options.widget_name] = [];
	},

	login:function(credentials){
		this.options.username = credentials.username.value;
		this.options.password = credentials.password.value;
		if(this.options.username.blank() && this.options.password.blank()) {
			this.alert_failure("Please provide Username and password.");
		} else {
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
		if(this.options.auth_type == 'OAuth'){
			if(this.options.url_auth) {
				if (reqData.resource == null) reqData.resource = reqData.rest_url;
				merge_sym = (reqData.resource.indexOf('?') == -1) ? '?' : '&';
				reqData.rest_url = reqData.resource + merge_sym + this.options.url_token_key + '=' + (this.options.password || this.options.oauth_token);
			}
			if(this.options.header_auth || !this.options.url_auth){
				reqHeader.Authorization = (this.options.useBearer?"Bearer ":"OAuth ") + 
										  (this.options.oauth_token || this.options.password);
			}
		}
		else if(this.options.auth_type == 'NoAuth'){}
		else if(this.options.auth_type == 'UAuth'){
			if (reqData.resource == null) reqData.resource = reqData.rest_url;
			merge_sym = (reqData.resource.indexOf('?') == -1) ? '?' : '&'
			reqData.rest_url = reqData.resource + merge_sym + this.options.url_token_key + '=' + this.options.username;
			reqData.app_name = this.options.app_name.toLowerCase().replace(' ', '_');
		}
		else if (this.options.auth_type == 'OAuth1') {
			reqData.auth_type = 'OAuth1';
			reqData.app_name = this.options.app_name.toLowerCase().replace(' ', '_');
		}
		else{
			reqHeader.Authorization = "Basic " + Base64.encode(this.options.username + ":" + this.options.password);
		}
		url = reqData.source_url ? reqData.source_url : this.http_proxy_url 
		var custom_callbacks = jQuery.extend(false, {}, reqData.custom_callbacks); // onXXX
		reqData.custom_callbacks = null
		var reqHeader_copy = jQuery.extend(false, {}, reqHeader)
		var reqObj=null;
		var req_obj = new Ajax.Request(url, reqObj=jQuery.extend(false, {
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
		
		if(this.ajax_queue != undefined){ // To push all ajax calls from a widget
			if(this.ajax_queue[this.options.widget_name] != undefined){
				this.ajax_queue[this.options.widget_name].push(req_obj);
			}
			else{
				this.ajax_queue[this.options.widget_name] = [req_obj];
			}
		}
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

    oauth_retry_error:function() {
        this.options.oauth_token = null;
        //console.log("OAuth refresh token refresh error for " + this.options.app_name + ". No  retries after 2 refresh attempts.");
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
                    (this.options.refresh_count > 2) ? this.oauth_retry_error() : this.options.refresh_count++;
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
				try {
					var error = XmlUtil.extractEntities(evt.responseXML,"error");
					if (error.length > 0) {
						err_msg = XmlUtil.getNodeValueStr(error[0], "message");
						alert(this.app_name+" reports the below error: \n\n" + err_msg + "\n\nTry again after correcting the error or fix the error manually.	");
						return;
					}
				}
				catch(ex) {
				}
				alert("Harvest reported an unknown error processing your Request.\n\n Your Timesheet might be locked. ");
				return;
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
				jQuery(".timeentry_status").hide(); // For timesheet apps, hiding the time_entry push flash message on failure
				errorStr = evt.responseText;
				this.alert_failure("Problem in connecting to " + this.app_name + ". Response code: " + evt.status);
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
		jQuery("#" + this.options.widget_name).removeClass('sloading loading-small');
		jQuery('#' + this.options.app_name.toLowerCase() + '_loading').remove();
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
		new Ajax.Request(this.access_token_renewal_url+this.options.app_name.toLowerCase().replace(' ', '_'), {
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

Freshdesk.NativeIntegration = {};

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
		jQuery(document).off("email_marketing");

		jQuery(document).on('click.email_marketing','#' + this.options.widget_name + ' .lists-submit', (function(ev){
			ev.preventDefault(); obj.manageLists();
		}));
		jQuery(document).on('click.email_marketing', '#' + this.options.widget_name + ' .contact-submit', (function(ev){
			ev.preventDefault(); obj.addUser();
		}));
		jQuery(document).on('click.email_marketing', '#' + this.options.widget_name + ' .newlists-submit', (function(ev){
			ev.preventDefault(); obj.newSubscribe();
		}));
		jQuery(document).on('click.email_marketing', '#' + this.app + '_widget ' + '.list-tab', (function(ev){
			ev.preventDefault(); obj.mailingLists();
		}));
		jQuery(document).on('click.email_marketing', "#" + this.app + "_widget " + ".campaign-tab", (function(ev){
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
		
		jQuery('#' + this.options.widget_name).removeClass('sloading loading-small');
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
			jQuery('#' + this.options.widget_name).addClass('sloading loading-small');
			
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
			jQuery('#'+lists[i]).prop('checked', true);
			this.mc_subscribe_lists.push(lists[i]);
		}
		jQuery('#' + this.options.widget_name + ' .lists input:unchecked').each(function() {
		  obj.mc_unsubscribe_lists.push($(this).id);
		});
		this.listsTmpl = jQuery('#' + this.options.widget_name + ' .lists-load')[0];
		jQuery('#' + this.options.widget_name + ' .lists-load').removeClass('hide');
		jQuery('#' + this.options.widget_name + ' .emailLists').removeClass('sloading loading-small');
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
				jQuery('#' + this.options.widget_name + ' .lists-load').removeClass('sloading loading-small').prepend("<hr/>");
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
		jQuery(document).off('.show-activity');
		jQuery(document).on('click.show-activity', '#show-activity-'+this.app ,function(ev){
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
		jQuery('#' + this.options.widget_name + ' .emailLists').addClass('sloading loading-small');
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
		jQuery(j + ' .emailLists').addClass('sloading loading-small');
		if(this.listsTmpl){
			jQuery(j + ' .emailLists').html(this.listsTmpl);
			jQuery(j + ' .lists-load').show();
			jQuery(j + ' .emailLists').removeClass('sloading loading-small');
		}
		else{
			this.getAllLists();
		}
			
	},

	renderModal: function(){
		var ecw = this;
		jQuery('#' + this.app + "_widget").removeClass('sloading loading-small');
		this.renderTemplate(_.template(this.Parent, {campaigns: this.campaignTmpl}));
	},

	renderUser: function(contact){
		contact = contact || {};
		contact.name = this.options.reqName;
		title = _.template(this.Title, {contact: contact, app: this.app});
		
		if(jQuery('#' + this.options.widget_name).data('modal') != undefined) {
			if((jQuery('#' + this.options.widget_name).data('modal').isShown === true) && 
				(!jQuery('#' + this.options.widget_name + '.modal').find('.email_marketing'))) {

				jQuery('#' + this.options.widget_name + '.modal').children('.modal-header').children('h3').remove();
				jQuery('#' + this.options.widget_name + '.modal').children('.modal-header').append(title);
			}
		}

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
			jQuery('#' + this.options.widget_name).removeClass('sloading loading-small');	
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
		jQuery('#' + this.app + "_widget").removeClass('sloading loading-small');
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
					'<div class="clearfix"> <h3 class="ellipsis modal-title pull-left"><%=contact.name%></h3><div class="application-logo-<%=app%> pull-right"></div></div><div class="cust-added"><%= (contact.since && contact.since != "") ? ("Customer since " + (new Date(contact.since.replace(/\-/g,"\/")).strftime("%a, %d %b %Y"))) : "" %></div>'+
				'</div>'+
			'</div>',

	Parent: '<div class="parent-container">'+
							'<div class="email_title"></div>'+
								'<div class="parent-tmpl">'+
									'<div class="modal-tabs">'+
										'<ul class="tabs nav-tabs">'+
											'<li class="active campaign-tab"><a href="#">Campaigns</a></li>'+
											'<li class="list-tab"><a href="#">MailingLists</a></li>'+
										'</ul>'+
									'</div>'+
									'<div class="emailCampaigns"><%=campaigns%></div>'+
									'<div class="hide emailLists"></div>'+
								'</div>'+
						'</div>',

	Export: '<hr/>'+
					'<div class="export-user">'+
						'<span><%=name%>&lt;<%=email%>&gt; cannot be found in <%=appname%></span>'+
						'<div class="button-container"><input type="submit" class="btn btn-primary contact-add contact-submit" value="Subscribe" /></div>'+
					'</div>'+
					'<div class="lists-load hide"></div>',


	NewLists: '<div class="mailing-msg"><b>Choose from the below mailing lists to add the contact and click Save</b></div>'+
						'<div class="all-lists"><div class="lists threecol-form"><%=lists%></div></div>' +
						'<div class="listsExportAll mt10"><input type="submit" class="btn btn-primary newlists-submit"  value="Save"></div>',
						


	Campaigns: '<div class="campaigns">'+
							'<div class="campaigns-list">'+
								'<% var keys = [];'+
										'if(app == "icontact"){'+
											'keys = _.keys(campaigns).reverse();'+
									    'for(i=0; i<keys.length; i++){ %>'+
								    		'<div id="show-activity-<%=app%>" class="activity-toggle <%=keys[i]%>"> <div class="campaign-activity"><div class="pull-left integrations-campaign-image"></div><%=campaigns[keys[i]].title%></div></div>'+
												'<div id="user-campaign-<%=keys[i]%>" class="hide loading-fb">'+
													'<div class="activities">'+
													'<div class="campaign-details hide"></div>'+
												'</div>'+
											'</div>'+
									    '<%}}else{'+
										 'for(key in campaigns){%><div id="show-activity-<%=app%>" class="activity-toggle <%=key%>"> <div class="campaign-activity"><div class="pull-left integrations-campaign-image"></div><%=campaigns[key].title%></div></div>'+
												'<div id="user-campaign-<%=key%>" class="hide loading-fb">'+
													'<div class="activities">'+
													'<div class="campaign-details hide"></div>'+
												'</div>'+
											'</div><%}}%>'+								
							'</div>'+
						'</div>',

	CampaignActivity: '<div class="activity"><div class="action_type"> <span class="action"> <%=action%> </span></div><span class="action-time"><%=action_time%></span><span class="action-url"><a href="<%=action_url%>" target="_blank"><span class="ficon-link url-icon"></span><%=action_url%></a></span> </div>',

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
			if(!this.options.handleRender){
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
		else{
				this.options.integratable_impl.handleRender(this.contacts,this);
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

(function($){
	Freshdesk.CRMCloudWidget = Class.create(Freshdesk.Widget,{
		initialize:function($super, widgetOptions, integratable_impl) { //widgetOptions is the Bundle(salesforceV2Bundle) and integratable_impl refers "this" of the CRM js.
			//app_name will be sent by individual js.
			//SFDC and Dynamics have the common objects. So, writing the same logic for both.
			if(widgetOptions.domain) {
				if(widgetOptions.reqEmail == ""){
					$super(widgetOptions);
					this.alert_failure('Email not available for this requester. A valid Email is required to fetch the contact from '+this.options.app_name);
				}else{
					this.fieldsHash = integratable_impl.fieldsHash;
					this.labelsHash = integratable_impl.labelsHash;
					widgetOptions.integratable_impl = integratable_impl;
					var cnt_req = this.get_contact_request(widgetOptions, integratable_impl);
					this.searchCount = cnt_req.length;
					this.searchResultsCount = 0;
					if(cnt_req){
						if(cnt_req.length == undefined) cnt_req = [cnt_req]
						for(var i=0;i<cnt_req.length;i++){
							cnt_req[i].on_success = this.handleContactSuccess.bind(this);
							if (widgetOptions.auth_type != 'OAuth' && integratable_impl.processFailure){
								cnt_req[i].on_failure = this.handleFailure.bind(this);              
							}
						}
						this.contacts = [];
						widgetOptions.init_requests = cnt_req;
					}
					$super(widgetOptions); // This will call the initialize method of Freshdesk.Widget.
				}
			}else{
				$super(widgetOptions);
				this.alert_failure('Domain name not configured. Try reinstalling '+this.options.app_name);
			}
		},
		get_contact_request: function(crmBundle, integratable_impl){
			crm_bundle = this.getBundle(crmBundle, integratable_impl); //crm_bundle is this.salesforceV2Bundle. crmBundle is salesforceV2Bundle
			var requestUrls = [];
			var custEmail = crm_bundle.reqEmail;
			requestUrls.push({type:"contact", value:custEmail});
			requestUrls.push({type:"lead", value:custEmail});
			var custCompany = crm_bundle.reqCompany;
			var ticket_company = crmBundle.ticket_company;
			if(crm_bundle.accountFields && crm_bundle.accountFields.length > 0){
				if(ticket_company && ticket_company.length > 0){ // fetch account by ticket filed company
					requestUrls.push({type:"account", value:{company:ticket_company}});
				}
				else if(custCompany  && custCompany.length > 0){
					custCompany = custCompany.trim(); 
					requestUrls.push({type:"account", value:{company:custCompany}});
				}
				else{
					requestUrls.push({type:"account", value:{email:custEmail}});
				}
			}
			for(var i=0;i<requestUrls.length;i++){
				requestUrls[i] = {  
					event:"fetch_user_selected_fields", 
					source_url:"/integrations/sync/crm/fetch",
					app_name: crmBundle.app_name,
					payload: JSON.stringify(requestUrls[i]) 
				}
			}
			return requestUrls;
		},
		getBundle: function(this_bundle, integratable_impl){
			var bundle;
			switch(this_bundle.app_name){
				case "salesforce_v2":
					bundle = integratable_impl.salesforceV2Bundle;
					break;
				case "dynamics_v2":
					bundle = integratable_impl.dynamicsV2Bundle;
					break;
				default:
					console.log("CRM not found error!");
			}
			return bundle;
		},
		handleFailure:function(response) {
			var message = "Problem occured while fetching the Entity";
			this.processFailure(response, message);
		},
		handleContactSuccess:function(response){
			var resJson = response.responseJSON;
			if(resJson == null){
				resJson = JSON.parse(response.responseText);      
			}
			if(this.contacts = this.contacts.concat(this.parse_contact(resJson, response))) {
				this.handleRender(this.contacts);
			}
		},
		handleRender:function(contacts){
			var _this= this;
			// handle the response from the requests.
			if ( !this.allResponsesReceived() ){
				return;       
			}
			this.loadIntegratedRemoteResource();
			if(contacts.length > 0) {
				if(contacts.length == 1) {
					this.processSingleResult(contacts[0]);
				}
				else{
					this.renderSearchResults();
				}
			} 
			else {
				this.processEmptyResults();
			}
			$("#"+_this.options.widget_name).removeClass('loading-fb');
		},
		processSingleResult:function(contact){
			if(contact.type == "Account"){ 
			//This will render single account and it also triggers related opportunities, contracts, orders
				this.account_related_calls_received = 0;
				if(this.options.opportunityView == "1"){
					this.account_related_calls_received++;
					this.getRelatedOpportunities(contact); 
				}
				if(this.options.contractView == "1"){
					this.account_related_calls_received++;
					this.getRelatedContracts(contact);
				}
				if(this.options.orderView == "1"){
					this.account_related_calls_received++;
					this.getRelatedOrders(contact);
				}
				if(this.account_related_calls_received == 0){
					this.renderContactWidget(contact);
				}
			}
			else{
				this.renderContactWidget(contact);
			}
		},
		processEmptyResults:function(){
			var _this = this;
			var customer_emails = this.options.reqEmails.split(",");
			if(customer_emails.length > 1){
				this.renderEmailSearchEmptyResults();
			}
			else{
				_this.renderContactNa();
			}
		},
		parse_contact: function(resJson){
			var contacts =[];
			if(resJson.records){
				resJson=resJson.records;      
			}
			var _this = this;
			resJson.each(function(contact) {
				var cLink = _this.getCRMLink(contact.Id, contact.attributes.type);
				// var cLink = this.salesforceV2Bundle.domain +"/"+contact.Id;
				var sfcontact ={};
				sfcontact['Id'] = contact.Id;
				sfcontact['url'] = cLink;//This sets the url to salesforce on name
				sfcontact['type'] = contact.attributes.type;
				//fieldsHash should be inside the initialize of the crm File in the format {"Contact": "Name,Title,Phone,...", "Account": "Name,..",...}
				var objectFields = _this.options.integratable_impl.fieldsHash[contact.attributes.type];
				if(objectFields!=undefined){
					objectFields = objectFields.split(",");
					for (var i=0;i<objectFields.length;i++){
						//Handle address for dynamics as well.
						if(objectFields[i]=="Address"){
							sfcontact[objectFields[i]]=_this.getAddress(contact.MailingStreet,contact.MailingState,contact.MailingCity,contact.MailingCountry);
						}
						else{
							sfcontact[objectFields[i]] = escapeHtml(_this.eliminateNullValues(contact[objectFields[i]]));
						}
					}
				}
				contacts.push(sfcontact);
			});
			return contacts;
		},
		loadIntegratedRemoteResource:function(){
			var _this = this;
			freshdeskWidget.request({
				event:"integrated_resource", 
				source_url:"/integrations/sync/crm/fetch",
				app_name: this.options.app_name,
				payload: JSON.stringify({ ticket_id:this.options.ticket_id }),
				on_success: function(response){
					response = response.responseJSON;
					if(!_.isEmpty(response)){
						_this.options.remote_integratable_id = response.remote_integratable_id;
					}
					else{
						_this.options.remote_integratable_id = "";
					}
				},
				on_failure: function(response){} 
			});
		},
		eliminateNullValues:function(input){
			return input || "NA";
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
		allResponsesReceived:function(){
			return (this.searchCount <= ++this.searchResultsCount );
		},
		renderEmailSearchEmptyResults:function(){
			var _this=this;
			_this.options.application_html = function(){ return _.template(_this.EMAIL_SEARCH_RESULTS_NA,{current_email:_this.options.reqEmail, app_name: _this.options.app_name});} 
			_this.display();
			_this.showMultipleEmailResults();
		},
		showMultipleEmailResults:function(){
			var customer_emails = this.options.reqEmails.split(",");
			var email_dropdown_opts = "";
			var selected_opt;
			var active_class;
			for(var i = 0; i < customer_emails.length; i++) {
				selected_opt = "";
				active_class = "";
				if(this.options.reqEmail == customer_emails[i]){
					selected_opt += '<span class="icon ticksymbol"></span>'
					active_class = " active";
				}
				email_dropdown_opts += '<a href="#" class="cust-email-v2'+active_class+'" data-email="'+customer_emails[i]+'">'+selected_opt+customer_emails[i]+'</a>';
			}
			$("#leftViewMenu"+ this.options.app_name +".fd-menu").html(email_dropdown_opts);
			$('#email-dropdown-div-' + this.options.app_name).show();
			this.bindEmailChangeEvent();
		},
		bindEmailChangeEvent:function(){
			var _this = this;
			//This will re-instantiate the crm object for every user email
			$(".fd-menu .cust-email-v2").on('click',function(ev){
				ev.preventDefault();
				// if(_this.options.app_name == "salesforce_v2"){
					_this.resetOpportunityDialog();         
				// }
				$("#"+ _this.options.widget_name +" .content").html("");
				var email = $(this).data('email');
				_this.options.integratable_impl.resetBundle(_this.options, email);
			});
		},
		renderSearchResults:function(){
			//for Contact, Account and Leads only.
			var crmResults="";
			var _this =this;
			for(var i=0; i<_this.contacts.length; i++){
				//Handle Name seperately
				var _contacts = _this.contacts[i];
				var name = _this.options.nameKeyFields[_contacts.type];
				crmResults += '<li><a class="multiple-contacts salesforce-tooltip" title="'+ _contacts[name] +'" href="#" data-contact="' + i + '">'+ _contacts[name] +'</a><span class="contact-search-result-type pull-right">'+_contacts.type+'</span></li>';
			}
			var results_number = {resLength: _this.contacts.length, requester: _this.options.reqEmail, resultsData: crmResults, app_name: _this.options.app_name};
			this.renderSearchResultsWidget(results_number);
			var _this = this;
			var crm_resource = undefined;
			$('#' + _this.options.widget_name).off('click','.multiple-contacts').on('click','.multiple-contacts', (function(ev){
				ev.preventDefault();
				crm_resource = _this.contacts[$(this).data('contact')];
				_this.handleCRMResource(crm_resource)
			}));
		},
		handleCRMResource:function(sf_resource){
			if(sf_resource.type == "Account"){ // This will handle opportunites if the opportunity_view is enabled
				if(!(this.options.opportunityView == "1" || this.options.contractView == "1" || this.options.orderView == "1")){
					this.renderContactWidget(sf_resource);                    
				}
				// Increment a counter Based on the number of request we are waiting.
				// Decrement the counter Inside the respective LoadObject: functions
				// If the Counter value is Zero Do the rendering. 
				this.account_related_calls_received = 0;
				if(this.options.opportunityView == "1"){
					var opportunity_records = this.options.opportunityHash[sf_resource.Id];        
						if(opportunity_records == undefined){
							this.account_related_calls_received++;
							this.getRelatedOpportunities(sf_resource);
						}
				}
				if(this.options.contractView == "1"){
					var contract_records = this.options.contractHash[sf_resource.Id];      
					if(contract_records == undefined){
						this.account_related_calls_received++;
						this.getRelatedContracts(sf_resource);
					}
				}
				if(this.options.orderView == "1"){
					var order_records = this.options.orderHash[sf_resource.Id];
					if(order_records == undefined){
						this.account_related_calls_received++;
						this.getRelatedOrders(sf_resource);
					}
				}
				if(this.account_related_calls_received == 0){
					this.renderContactWidget(sf_resource);                    
				}
			}
			else{
				this.renderContactWidget(sf_resource);
			}
		},
		renderSearchResultsWidget:function(results_number){
			var _this=this;
			var customer_emails = _this.options.reqEmails.split(",");
			results_number.widget_name = _this.options.widget_name; //_this.options.salesforce_widget_name;
			results_number.current_email = _this.options.reqEmail;
			var resultsTemplate = "";
			resultsTemplate = customer_emails.length > 1 ? _this.CONTACT_SEARCH_RESULTS_MULTIPLE_EMAILS : _this.CONTACT_SEARCH_RESULTS;
			_this.options.application_html = function(){ return _.template(resultsTemplate, results_number); } 
			_this.display();
			if(customer_emails.length > 1){
				_this.showMultipleEmailResults();
			}
		},
		renderContactWidget:function(eval_params){
			var _this = this;
			var customer_emails = _this.options.reqEmails.split(",");
			var name_field = _this.options.nameKeyFields[eval_params.type];
			eval_params.Name = eval_params[name_field];
			eval_params.count = _this.contacts.length;
			eval_params.app_name = _this.options.app_name;
			eval_params.widget_name = _this.options.widget_name;
			eval_params.type = eval_params.type?eval_params.type:"" ; 
			eval_params.department = eval_params.department?eval_params.department:null;
			eval_params.url = this.getCRMLink(eval_params.Id, eval_params.type);
			// Handle address differerently for Dynamics and SFDC.
			eval_params.address_type_span = eval_params.address_type_span || " ";
			eval_params.current_email = _this.options.reqEmail;
			var contact_fields_template="";
			contact_fields_template = this.getTemplate(eval_params);
			var contact_template = (customer_emails.length > 1 && eval_params.count == 1)  ? _this.VIEW_CONTACT_MULTIPLE_EMAILS : _this.VIEW_CONTACT;
			_this.options.application_html = function(){ return _.template(contact_template, eval_params)+""+contact_fields_template; } 
			this.removeError();
			this.removeLoadingIcon();
			_this.display();
			this.bindParagraphReadMoreEvents();
			if(customer_emails.length > 1 && eval_params.count == 1){
				_this.showMultipleEmailResults();
			}
			var _this = this;
			$('#' + _this.options.widget_name).on('click','#search-back', (function(ev){
				ev.preventDefault();
				_this.resetOpportunityDialog();
				_this.renderSearchResults();
			}));
			if(eval_params.type == "Account"){
				_this.handleOpportunitesSection(eval_params);
				_this.handleContractsSection(eval_params);
				_this.handleOrdersSection(eval_params);
			}
		},
		handleOpportunitesSection:function(eval_params){
			var _this = this;
			var opportunity_records = crm_bundle.opportunityHash[eval_params.Id];
			var create_opportunity_element = "#create_new_opp_" + _this.options.app_name;
			if($(create_opportunity_element).length){
				$(".salesforce_v2_contacts_widget_bg").on('click',create_opportunity_element,(function(ev){
						ev.preventDefault();
						_this.bindOpportunitySubmitEvents(eval_params);
				}));
			}
			if(opportunity_records && opportunity_records.length){
				_this.bindAccountObjectEvents("opportunities");
				_this.bindOpportunityLinkEvents(eval_params);
			}
		},
		handleContractsSection:function(eval_params){
			var _this = this;
			var contract_records = crm_bundle.contractHash[eval_params.Id];
			if(contract_records && contract_records.length){
				_this.bindAccountObjectEvents("contracts");
			}
		},
		handleOrdersSection:function(eval_params){
			var _this = this;
			var order_records = crm_bundle.orderHash[eval_params.Id];
			if(order_records && order_records.length){
				_this.bindAccountObjectEvents("orders");
			}
		},
		getRelatedOpportunities:function(eval_params,linkFlag){
			var _this = this;
			this.showLoadingIcon(_this.options.widget_name);
			freshdeskWidget.request({
				event:"fetch_user_selected_fields", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:_this.options.app_name,
				payload: JSON.stringify({ type:"opportunity", value:{ account_id:eval_params.Id }, ticket_id:_this.options.ticket_id }),
				on_success: function(response){
						response = response.responseJSON;
						_this.loadOpportunities(response,eval_params,linkFlag);
				},
				on_failure: function(response){
						var message = "Problem occured while fetching opportunties";
						_this.processFailure(eval_params,message);
				} 
			});
		},
		loadOpportunities:function(response,eval_params,linkFlag){
			var opp_records = response.records;
			var error;
			var _this = this;
			if(opp_records.length > 0){
				var opp_fields = crm_bundle.opportunityFields.split(",");
				for(i=0;i<opp_records.length;i++){
					for(j=0;j<opp_fields.length;j++){
						var value = opp_records[i][opp_fields[j]];
						if(typeof value == "boolean"){
							continue;
						}
						if(opp_fields[j] == "attributes.salesstage" && value !== null && value !== undefined){
							// To display the salesstage for the dynamics.
							var stage_options = _this.options.opportunity_stage;
							for(k=0;k<stage_options.length;k++){
								if(stage_options[k][1] === value.toString()){
									opp_records[i][opp_fields[j]] = stage_options[k][0];
									break;
								}
							}
							continue;
						}
						opp_records[i][opp_fields[j]] = escapeHtml(_this.eliminateNullValues(value));
						if(opp_records[i][opp_fields[j]] !== "NA" && ["CloseDate", "attributes.estimatedclosedate"].indexOf(opp_fields[j]) !== -1){
							//Converting close date to user readable format
							opp_records[i][opp_fields[j]] = _this.convertDate(opp_records[i][opp_fields[j]])
						}
					}
				}
				_this.options.opportunityHash[eval_params.Id] = opp_records;
			}
			else{
				_this.options.opportunityHash[eval_params.Id] = [];
			}
			if(eval_params.error){ // This will show error in the opportunities section
				error = eval_params.error;
				eval_params.error = undefined;
				_this.processFailure(eval_params,error);
			}else{
				if(--_this.account_related_calls_received == 0){
					_this.renderContactWidget(eval_params);
				}
			}
		},
		getRelatedContracts:function(eval_params){
			var _this = this;
			this.showLoadingIcon(_this.options.widget_name);
			freshdeskWidget.request({
				event:"fetch_user_selected_fields", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:_this.options.app_name,
				payload: JSON.stringify({ type:"contract", value:{ account_id:eval_params.Id } }),
				on_success: function(response){
					response = response.responseJSON;
					_this.loadContracts(response,eval_params);
				},
				on_failure: function(response){
					var message = "Problem occured while fetching contracts";
					_this.processFailure(eval_params,message);
				} 
			});
		},
		loadContracts:function(response,eval_params){
			var _this = this;
			var contract_records = response.records;
			var error;
			if(contract_records.length > 0){
				var contract_fields = crm_bundle.contractFields.split(",");
				for(i=0;i<contract_records.length;i++){
					for(j=0;j<contract_fields.length;j++){
						if(typeof contract_records[i][contract_fields[j]] == "boolean"){
							continue;
						}
						contract_records[i][contract_fields[j]] = escapeHtml(_this.eliminateNullValues(contract_records[i][contract_fields[j]]));
						if(contract_records[i][contract_fields[j]] !== "NA" && ["StartDate", "attributes.activeon", "attributes.expireson"].indexOf(contract_fields[j]) !== -1 ){ //Converting start date to user readable format
							contract_records[i][contract_fields[j]] = _this.convertDate(contract_records[i][contract_fields[j]]);
						}
					}
				}
				_this.options.contractHash[eval_params.Id] = contract_records;
			}
			else{
				_this.options.contractHash[eval_params.Id] = [];
			}
			if(eval_params.error){ // This will show error in the contract section
				error = eval_params.error;
				eval_params.error = undefined;
				_this.processFailure(eval_params,error);
			}else{
				if(--_this.account_related_calls_received == 0){
					_this.renderContactWidget(eval_params);
				}
			}
		},
		getRelatedOrders:function(eval_params){
			var _this =this;
			this.showLoadingIcon(_this.options.widget_name);
			freshdeskWidget.request({
				event:"fetch_user_selected_fields", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:_this.options.app_name,
				payload: JSON.stringify({ type:"order", value:{ account_id:eval_params.Id } }),
				on_success: function(response){
					response = response.responseJSON;
					_this.loadOrders(response,eval_params);
				},
				on_failure: function(response){
					var message = "Problem occured while fetching orders";
					_this.processFailure(eval_params,message);
				} 
			});
		},
		loadOrders:function(response,eval_params){
			var order_records = response.records;
			var error=undefined;
			var _this = this;
			if(order_records.length > 0){
				var order_fields = crm_bundle.orderFields.split(",");
				for(i=0;i<order_records.length;i++){
					for(j=0;j<order_fields.length;j++){
						if(typeof order_records[i][order_fields[j]] == "boolean"){
							continue;
						}
						order_records[i][order_fields[j]] = escapeHtml(_this.eliminateNullValues(order_records[i][order_fields[j]]));
						if( order_records[i][order_fields[j]] !== "NA" && ["EffectiveDate", "attributes.createdon"].indexOf(order_fields[j]) !== -1){ //Converting start date to user readable format
							order_records[i][order_fields[j]] = _this.convertDate(order_records[i][order_fields[j]]);
						}
					}
				}
				_this.options.orderHash[eval_params.Id] = order_records;
			}
			else{
				_this.options.orderHash[eval_params.Id] = [];
			}
			if(eval_params.error){ // This will show error in the order section
				error = eval_params.error;
				eval_params.error = undefined;
				_this.processFailure(eval_params,error);
			}
			else{
				if(--_this.account_related_calls_received == 0){
					_this.renderContactWidget(eval_params);                    
				}
			}
		},
		bindOpportunitySubmitEvents:function(eval_params){
			var _this = this;
			var account_id = eval_params.Id;
			this.clearOpportunityFormErrors();
			$("#opportunity-submit-"+ _this.options.app_name + "-" + account_id).off('click').on('click',function(ev){
				ev.preventDefault();
				$(this).attr("disabled","disabled").val("Creating...");
				_this.createOpportunity(eval_params);
			});
			$("#opportunity-cancel-"+ _this.options.app_name + "-" + account_id).off('click').on('click',function(ev){
				ev.preventDefault();
				$("#create_sf_opportunity_"+ _this.options.app_name + "_"+account_id).modal("hide");
				_this.resetOpportunityForm(account_id);
			});
			$("#create_sf_opportunity_"+ _this.options.app_name + "_" + account_id + " .close").on('click',function(ev){
				ev.preventDefault();
				_this.resetOpportunityForm(account_id);
			});
		},
		createOpportunity:function(eval_params){
			var _this = this;
			if(this.validateInput()){
				$("#opportunity-validation-errors-"+ _this.options.app_name).hide();
				var date = new Date($("#opportunity_close_date_" + _this.options.app_name).val());
				var stage_name = $("#opportunity_stage_"+ _this.options.app_name ).val();
				var name = $("#opportunity_name_"+ _this.options.app_name ).val();
				var amount = $("#opportunity_amount_"+ _this.options.app_name ).val();
				//build seperate opportunity params for Salesforce and dynamics.
				// var opportunity_params = { ticket_id:this.options.ticket_id, AccountId:eval_params.Id,Name:name, CloseDate:date, StageName:stage_name, Amount:amount,type:"opportunity"};
				var opportunity_params = _this.getOpportunitiesParams(eval_params ,name, date, stage_name, amount);
				freshdeskWidget.request({
					event:"create_opportunity", 
					source_url:"/integrations/sync/crm/fetch",
					app_name:_this.options.app_name,
					payload: JSON.stringify(opportunity_params),
					on_success:function(response){
						response = response.responseJSON;
						_this.processOpportunityPostCreate(response,eval_params);
					},
					on_failure:function(response){
						var message = response.responseJSON.message || response.responseJSON;
						$("#opportunity-submit-"+ _this.options.app_name + "-" + eval_params.Id).removeAttr('disabled').val("Create");
						$(".salesforce-opportunity-custom-errors-v2").show().html("<span>Opportunity creation failed."+" "+message+"</span>");
					} 
				});
			}
			else{
				$(".salesforce-opportunity-custom-errors-v2").hide();
				$("#opportunity-submit-"+ _this.options.app_name + "-" + eval_params.Id).removeAttr('disabled').val("Create");
			}
		},
		getOpportunitiesParams: function(eval_params ,name, date, stage_name, amount){
			var _this = this, opportunityParams = {};
			switch(_this.options.app_name){
				case "salesforce_v2":
					date = date.toString("yyyy-MM-dd");
					opportunityParams = { ticket_id:_this.options.ticket_id, type:"opportunity", AccountId:eval_params.Id, Name:name, CloseDate:date, StageName:stage_name, Amount:amount};
				break;
				case "dynamics_v2":
					date = date.getTime();
					//add stageName once resolved.
					opportunityParams = { ticket_id:_this.options.ticket_id,  type:"opportunity", attributes: {customerid:eval_params.Id, name:name, estimatedclosedate:date, estimatedvalue:amount, salesstage:stage_name}, 'fetchMetaInfo':true};
				break;
				default:
			}
			return opportunityParams;
		},
		bindAccountObjectEvents: function(object){ //opportunities, contracts, orders.
			$(".multiple-" + object).click(function(ev){
				ev.preventDefault();
				var _this = $(this);
				if(_this.parent().next(".opportunity_details").css('display') != 'none'){
					if(object === "opportunities"){
						$(".opportunity_link").hide();
						$(".opp-flag").show();
					}
					_this.toggleClass('active');
					_this.parent().next(".opportunity_details").hide();
				}else{
					$(".opportunity_link").hide();
					if(object === "opportunities"){
						_this.siblings(".opp-flag").hide();
						_this.next(".opportunity_link").show();
					}else{
						$(".opp-flag").show();
					}
					$(".salesforce-opportunity-tooltip").each(function(){
						var _self = $(this);
						if(_self !== _this){
							_self.removeClass('active');
						}
					});
					$(".opportunity_details").hide();
					_this.toggleClass("active");
					_this.parent().next(".opportunity_details").show();
				}
			});
		},
		bindOpportunityLinkEvents:function(eval_params){
			var _this = this;
			$(".Link").off('click').on('click',function(ev){
				ev.preventDefault();
				var opportunity_id = $(this).attr('id');
				_this.linkOpportunity(opportunity_id,eval_params);
			});
			$(".Unlink").off('click').on('click',function(ev){
				ev.preventDefault();
				var opportunity_id = $(this).attr('id');
				_this.unlinkOpportunity(opportunity_id,eval_params);
			});
		},
		processOpportunityPostCreate:function(response,eval_params){
			$("#create_sf_opportunity_"+ this.options.app_name + "_"+eval_params.Id).modal("hide");
			this.resetOpportunityForm(eval_params.Id);
			this.linkOpportunity(response.Id,eval_params);
		},
		removeOtherAccountOpportunities:function(eval_params){
			for(key in crm_bundle.opportunityHash){
				if (key != eval_params.Id){
					crm_bundle.opportunityHash[key] = undefined;
				}
			}
		},
		linkOpportunity:function(opportunity_id,eval_params){
			var _this = this;
			this.resetOpportunityDialog();
			// when two apps are installed two widgets will be loading.
			this.showLoadingIcon(_this.options.widget_name);
			freshdeskWidget.request({
				event:"link_opportunity", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:_this.options.app_name,
				payload: JSON.stringify({ ticket_id:_this.options.ticket_id, remote_id:opportunity_id }),
				on_success: function(response){
					response = response.responseJSON;
					_this.handleOpportunityLink(response,eval_params,opportunity_id,true);
				},
				on_failure: function(response){
					var message = response.responseJSON.message || response.responseJSON;
					_this.processFailure(eval_params,message);
				} 
			});
		},
		handleOpportunityLink:function(response,eval_params,opportunity_id,linkStatus){
			if(response.error){
				eval_params.error = response.error;
				this.options.remote_integratable_id = response.remote_id;
				this.removeOtherAccountOpportunities(eval_params);
				this.account_related_calls_received = 1;
				this.getRelatedOpportunities(eval_params);
				if(this.options.contractView == "1"){
					this.account_related_calls_received++;
					this.getRelatedContracts(eval_params); 
				}
				if(this.options.orderView == "1"){
					this.account_related_calls_received++;
					this.getRelatedOrders(eval_params);
				}
			}
			else{
				this.options.remote_integratable_id = linkStatus ? opportunity_id : "";
				this.resetOtherAccountOpportunities(eval_params,linkStatus);
				this.account_related_calls_received = 1;
				this.getRelatedOpportunities(eval_params,linkStatus);
				if(this.options.contractView == "1"){
					this.account_related_calls_received++;
					this.getRelatedContracts(eval_params);
				}
				if(this.options.orderView == "1"){
					this.account_related_calls_received++;        
					this.getRelatedOrders(eval_params);
				}
			}
		},
		resetOtherAccountOpportunities:function(eval_params,link_status){
			var records = undefined;
			for(key in crm_bundle.opportunityHash){
				records = crm_bundle.opportunityHash[key];
				if (key != eval_params.Id && records.length){
					for(i=0;i<records.length;i++){
						records[i]["link_status"] = link_status;
					}
					crm_bundle.opportunityHash[key] = records;
				}
			}
		},
		unlinkOpportunity:function(opportunity_id,eval_params){
			var _this = this;
			this.showLoadingIcon(_this.options.widget_name);
			freshdeskWidget.request({
				event:"unlink_opportunity", 
				source_url:"/integrations/sync/crm/fetch",
				app_name:_this.options.app_name,
				payload: JSON.stringify({ ticket_id:_this.options.ticket_id, remote_id:opportunity_id }),
				on_success: function(response){
					response = response.responseJSON;
					_this.handleOpportunityLink(response,eval_params,opportunity_id,false);
				},
				on_failure: function(response){
					var message = response.responseJSON.message || response.responseJSON;
					_this.processFailure(eval_params,message);
				} 
			});
		},
		validateInput:function(){
			var _this= this;
			var datecheck = new Date($("#opportunity_close_date_" + this.options.app_name).val().trim());
			$(".salesforce-opportunity-custom-errors-v2").hide();
			if(!$("#opportunity_name_"+ _this.options.app_name).val().trim()){
				this.showValidationErrors("Please enter a name");
				return false;
			}
			if(!$("#opportunity_stage_"+ _this.options.app_name).val().trim()){
				this.showValidationErrors("Please select an opportunity stage");
				return false;
			}
			if(!$("#opportunity_close_date_" + this.options.app_name).val().trim() || datecheck.toString() == "Invalid Date"){
				this.showValidationErrors("Enter value for close date");
				return false;
			}	
			var opp_amount = $("#opportunity_amount_"+ _this.options.app_name);
			if(opp_amount.val().trim() && isNaN(opp_amount.val())){
				this.showValidationErrors("Please enter valid amount");
				return false;
			}
			return true;
		},
		resetOpportunityForm:function(account_id){
			var _this = this;
			this.clearOpportunityFormErrors();
			$("#opportunity-submit-" + this.options.app_name + "-" + account_id).removeAttr('disabled').val("Create");
			$("#opportunity_stage_" + this.options.app_name ).select2("val",crm_bundle.opportunity_stage[0][1]);
			$("#salesforce-opportunity-form-" + this.options.app_name)[0].reset();
		},
		resetOpportunityDialog:function(){
			var create_opportunity_element = "#create_new_opp_" + this.options.app_name;
			if($(create_opportunity_element).data("freshdialog")){
				$("#"+ $(create_opportunity_element).data("freshdialog").$dialogid).remove();
			}
		},
		clearOpportunityFormErrors:function(){
			$("#opportunity-validation-errors-"+ this.options.app_name).hide();
			$(".salesforce-opportunity-custom-errors-v2").hide();
		},
		showValidationErrors:function(msg){
			var sf_val_error = $("#opportunity-validation-errors-"+ this.options.app_name);
			sf_val_error.text(msg);
			sf_val_error.show();
		},
		showLoadingIcon:function(widget_name){
			$("#"+widget_name+" .content").html("");
			$("#"+widget_name).addClass('sloading loading-small');
		},
		processFailure:function(eval_params,msg){
			this.renderContactWidget(eval_params);
			this.showError(msg);
		},
		showError:function(message){
			freshdeskWidget.alert_failure("The following error is reported:"+" "+message);
		},
		removeError:function(){
			$("#" + this.options.widget_name + " .error").html("").addClass('hide');
		},
		removeLoadingIcon:function(){
			$("#" + this.options.widget_name).removeClass('sloading loading-small');
		},
		bindParagraphReadMoreEvents:function(){
			var i = 1;
			$(".para-less").each(function(){
			var _this = $(this);
				if(_this.actual('height') > 48){ // This event uses jquery.actual.min.js plugin to find the height of hidden element
					_this.addClass('para-min-lines');
					_this.attr('tabIndex',i);
					_this.next(".toggle-para").addClass('active-para').removeClass('hide');
					i++;
				}
			});
			$('.toggle-para.active-para p').click(function(){
			var _this = $(this);
			_this.parent().toggleClass('q-para-span');
			_this.parent().prev(".para-less").toggleClass('para-min-lines para-max-lines');
			_this.toggleClass('q-marker-more q-marker-less');
			_this.parent().prev(".para-less").focus();
				});
		},
		renderContactNa:function(){
			var _this=this;
			_this.options.url = _this.options.url || "#";
			this.options.application_html = function(){ return _.template(_this.CONTACT_NA, _this.options);} 
			this.display();
		},
		//======================================== ALL TEMPLATES ========================================================================
		getTemplate:function(eval_params){
			var resourceTemplate = "";
			var fields;
			var labels;
			var _this =this;
			switch(eval_params.type){
				case "Lead":
					fields = _this.options.leadFields.split(",");
					labels = _this.options.integratable_impl.leadInfo;
					resourceTemplate = _this.resourceSectionTemplate(fields,labels,eval_params);
				break;
				case "Account":
					fields = _this.options.accountFields.split(",");
					labels = _this.options.integratable_impl.accountInfo;
					var accountsTemplate = _this.resourceSectionTemplate(fields,labels,eval_params);
					var opportunity_records = _this.options.opportunityHash[eval_params.Id];
					var contract_records = _this.options.contractHash[eval_params.Id];
					var order_records = _this.options.orderHash[eval_params.Id];
					resourceTemplate = accountsTemplate;
					if(opportunity_records && _this.options.opportunityView == "1"){
						if(opportunity_records.length){
							resourceTemplate += _this.getOpportunitiesTemplate(opportunity_records,eval_params);
						}
						else{
							resourceTemplate += _this.getEmptyOpportunitiesTemplate(eval_params);
						}
					}
					if(contract_records && _this.options.contractView == "1"){
						if(contract_records.length){
							resourceTemplate += _this.getContractsTemplate(contract_records,eval_params);
						}
						else{
							resourceTemplate += _this.getEmptyContractsTemplate(eval_params);
						}
					}
					if(order_records && _this.options.orderView == "1"){
						if(order_records.length){
							resourceTemplate += _this.getOrdersTemplate(order_records,eval_params);
						}
						else{
							resourceTemplate += _this.getEmptyOrdersTemplate(eval_params);
						}
					}
				break;
				case "Contact":
					labels = _this.options.integratable_impl.contactInfo;
					fields = _this.options.contactFields.split(",");
					resourceTemplate = _this.resourceSectionTemplate(fields,labels,eval_params);
				break;
				default:
			}
			return resourceTemplate;
		},
		resourceSectionTemplate:function(fields,labels,eval_params){
			var _this = this;
			var contactTemplate ="";
			var keyEntities = ["Account", "Contact", "Lead"];
			var accountEntities = ["Opportunity", "Order", "Contract"];
			for(var i=0;i<fields.length;i++){
				var value = eval_params[fields[i]];
				//Contact, Account, Lead Headers should be continue;
				if(this.options.headerFields.indexOf(fields[i]) !== -1 && keyEntities.indexOf(eval_params.type) !== -1 ){ 
					/* Salesforce_v2
						Name field of Contact, Account and Leads for Salesforce will be the headers.
						Name field of Opportunity will also be the header. But we will be appending the link with the Name field in the body section.
						For Contract and Order ContractNumber and OrderNumber will be the headers. So, it will be added to the body.
					*/
					/*  Dynamics_v2
						fullname and name should be continued. name should not be continued for Order and Opportunity. 
					*/
					continue;
				}
				// Placing external link in the header field of opportunity, contract and orders
				if(this.options.headerFields.indexOf(fields[i]) !== -1 && accountEntities.indexOf(eval_params.type) !== -1){
					var external_link = _this.getCRMLink(eval_params.Id, eval_params.type)
					contactTemplate += _.template(this.ACCOUNT_ENTITY_TEMPLATE, {external_link: external_link, value: value, label: labels[fields[i]], field: fields[i]});
					continue;
				}
				value = (typeof value === "boolean")? (value) : (value|| "N/A");
				contactTemplate += _.template(this.COMMON_CONTACT_TEMPLATE, {value: value, label: labels[fields[i]], field: fields[i]});
			}
			if(eval_params.type == "Opportunity" ||eval_params.type == "Contract" || eval_params.type == "Order"){ // list of user selected fields, hidden at first
				contactTemplate = _.template('<div class="opportunity_details mt5 ml12 hide"><%=contactTemplate%></div>',{contactTemplate:contactTemplate});
			}
			return contactTemplate;
		},
		getOpportunitiesTemplate:function(opportunity_records,eval_params){
			var opportunities_template = "";
			for(var i=0;i<opportunity_records.length;i++){
				opportunities_template += this.getOpportunityDetailsTemplate(opportunity_records[i]);
			}
			var opportunity = this.getOpportunityCreateTemplate(eval_params);
			opportunities_template = _.template(this.OPPORTUNITY_SEARCH_RESULTS,{resultsData:opportunities_template,opportunityCreateLink:opportunity.create_template,opportunityForm:opportunity.form_template});
			return opportunities_template;
		},
		getOpportunityDetailsTemplate:function(opportunity_record){
			// for each opp record
			var opportunity_template = "";
			var opportunity_list_item = "";
			// To link a opportunity with a ticket not needed for contracts and orders
			var opportunity_link_template = "<span class='hide opportunity_link pull-right'><a href='#' class='#{opportunity_status}' id='#{opportunity_id}'>#{opportunity_status}</a></span>";
			var link_status = (opportunity_record["link_status"] == undefined) ? "" : opportunity_record["link_status"];
			var unlink_status = (opportunity_record["unlink_status"] == undefined) ? "" : opportunity_record["unlink_status"];
			opportunity_link_template = (this.options.agentSettings == "1") ? opportunity_link_template : "";
			if(link_status && unlink_status){
				// Deleted flag will be shown for linked deleted opportunities
				//Will be different for dynamics
				//In dynamics Deleted opportunity will be returned a 500 code so we have to handle it seperately.
				if(opportunity_record["IsDeleted"]){ 
					opportunity_link_template += "<div class='opp-flag pull-right'>Deleted</div>";
				}
				else{
					opportunity_link_template += "<div class='opp-flag pull-right'>Linked</div>";
				}
				opportunity_list_item += opportunity_link_template.interpolate({opportunity_id:opportunity_record.Id,opportunity_status:"Unlink"});
			}
			else if(link_status === false){
				opportunity_list_item += opportunity_link_template.interpolate({opportunity_id:opportunity_record.Id,opportunity_status:"Link"});
			}
			opportunity_record["type"] = opportunity_record.type || "Opportunity";
			var header = this.options.nameKeyFields[opportunity_record.type];
			var name = opportunity_record[header];
			opportunity_template += '<li><a class="multiple-opportunities salesforce-opportunity-tooltip" title="'+opportunity_record.Name+'" href="#">'+ name +'</a>'+opportunity_list_item+'</li>';
			opportunity_template += this.resourceSectionTemplate(crm_bundle.opportunityFields.split(","), this.options.integratable_impl.opportunityInfo, opportunity_record);
			return opportunity_template;
		},
		getOpportunityCreateTemplate:function(eval_params){
			var opportunity_create_template = "";
			var opportunity_form = "";
			var result = undefined;
			var _this = this;
			if(!this.options.remote_integratable_id && this.options.ticket_id){
				if(this.options.agentSettings == "1"){
					opportunity_create_template += '<div class="opportunity_create pull-right"><span class="contact-search-result-type"><a id="create_new_opp_' + this.options.app_name +'" href="#" rel="freshdialog" data-target="#create_sf_opportunity_'+ this.options.app_name +'_'+eval_params.Id+'" data-title="Create Opportunity" data-width="500" data-keyboard="false" data-template-footer="">Create New</a></span></div>';
					var stage_options = this.options.opportunity_stage;
					var stage_dropdown_options = "";
					for(i=0;i<stage_options.length;i++){
						stage_dropdown_options += '<option id="'+i+'" value="'+stage_options[i][1]+'">'+stage_options[i][0]+'</option>';
					}
					opportunity_form += JST["app/integrations/salesforce_v2/opportunity_create_form"]({
						stage_options:stage_dropdown_options,
						account_id:eval_params.Id,
						app_name:_this.options.app_name
					});
				}
			}
			result = {create_template:opportunity_create_template,form_template:opportunity_form};
			return result;
		},
		getEmptyOpportunitiesTemplate:function(eval_params){
			var opportunity = this.getOpportunityCreateTemplate(eval_params);
			var opportunities_template = _.template(this.OPPORTUNITY_SEARCH_RESULTS_NA,{opportunityCreateLink:opportunity.create_template,opportunityForm:opportunity.form_template});
			return opportunities_template;
		},
		getContractsTemplate:function(contract_records,eval_params){
			var contracts_template = "";
			for(var i=0;i<contract_records.length;i++){
				contracts_template += this.getContractDetailsTemplate(contract_records[i]);
			}
			contracts_template = JST["app/integrations/salesforce_v2/object_search_results"]({resultsData:contracts_template, object_name: "Contracts", object_field: "contracts"});
			return contracts_template;
		},
		getContractDetailsTemplate:function(contract_record){
			var contract_template = "";
			var contract_list_item = "";
			contract_record["type"] = contract_record.type || "Contract";
			var header = this.options.nameKeyFields[contract_record.type];
			var name = contract_record[header];
			contract_template += '<li><a class="multiple-contracts salesforce-opportunity-tooltip" title="'+ name +'" href="#">'+ name +'</a>'+contract_list_item+'</li>';
			contract_template += this.resourceSectionTemplate(this.options.contractFields.split(","),this.options.integratable_impl.contractInfo,contract_record);
			return contract_template;
		},
		getOrdersTemplate:function(order_records,eval_params){
			var orders_template = "";
			for(var i=0;i<order_records.length;i++){
				orders_template += this.getOrderDetailsTemplate(order_records[i]);
			}
			orders_template = JST["app/integrations/salesforce_v2/object_search_results"]({resultsData:orders_template, object_name: "Orders", object_field: "orders"});
			return orders_template;
		},
		getOrderDetailsTemplate:function(order_record){
			var order_template = "";
			var order_list_item = "";
			order_record["type"] = order_record.type || "Order";
			var header = this.options.nameKeyFields[order_record.type];
			var name = order_record[header];
			order_template += '<li><a class="multiple-orders salesforce-opportunity-tooltip" title="'+ name +'" href="#">'+ name +'</a>'+order_list_item+'</li>';
			order_template += this.resourceSectionTemplate(this.options.orderFields.split(","),this.options.integratable_impl.orderInfo,order_record);
			return order_template;
		},
		getEmptyOrdersTemplate:function(eval_params){
			var orders_template = JST["app/integrations/salesforce_v2/object_search_results_na"]({object_name: "Orders", object_field: "orders"});
			return orders_template;
		},
		getEmptyContractsTemplate:function(eval_params){
			var contracts_template = JST["app/integrations/salesforce_v2/object_search_results_na"]({object_name: "Contracts", object_field: "contracts"});
			return contracts_template;
		},
		//======================================== ALL HELPERS ========================================================================
		getCRMLink:function(Id, type){
			var link;
			switch(this.options.app_name){
				case "salesforce_v2":
					link = this.options.domain+"/"+Id;
					break;
				case "dynamics_v2":
					link = this.options.domain + "/main.aspx?etn=" + this.options.objects[type] + "&pagetype=entityrecord&id=%7B" + Id + "%7D"
					break;
			}
			return link;
		},
		convertDate: function(date){
			if(!isNaN(date)){
				date = parseInt(date);
			}
			var newDate = new Date(date);
			return newDate.toString("dd MMM, yyyy");
			// return (("0" + newDate.getDate()).slice(-2) + " " +("0" + newDate.getMonth()).slice(-2) + ", " + newDate.getFullYear());
		},
		VIEW_CONTACT:
		'<div class="title salesforce_v2_contacts_widget_bg">' +
			'<div class="row-fluid">' +
				'<div id="contact-name" class="span8">'+
				'<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
				'<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=Name%></a></div>' +
				'<div class="span4 pt3"><span class="contact-search-result-type pull-right"><%=(type || "")%></span></div>'+
			'</div>' + 
		'</div>',
		VIEW_CONTACT_MULTIPLE_EMAILS:
		'<div class="title salesforce_v2_contacts_widget_bg">' +
			'<div id="email-dropdown-div-<%=app_name%>" class="view_filters mb10 hide"><div class="link_item"><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu<%=app_name%>"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu<%=app_name%>" style="display: none; visibility: visible;"></div></div>'+
			'<div class="single-result row-fluid">' +
				'<div id="contact-name" class="span8">'+
				'<a id="search-back" href="#"><div class="search-back <%=(count>1 ? "": "hide")%>"> <i class="arrow-left"></i> </div></a>'+
				'<a title="<%=Name%>" target="_blank" href="<%=url%>" class="sales-title salesforce-tooltip"><%=Name%></a></div>' +
				'<div class="span4 pt3"><span class="contact-search-result-type pull-right"><%=(type || "")%></span></div>'+
			'</div>' + 
		'</div>',
		EMAIL_SEARCH_RESULTS_NA:
		'<div class="title salesforce_v2_contacts_widget_bg">' +
			'<div id="email-dropdown-div-<%=app_name%>" class="view_filters hide"><div class="link_item"><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu<%=app_name%>"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu<%=app_name%>" style="display: none; visibility: visible;"></div></div>'+
			'<div id="search-results" class="mt20">'+
			'<span id="contact-na">No results found for <%=current_email%></span>'+
			'</div>'+
		'</div>',
		CONTACT_SEARCH_RESULTS_MULTIPLE_EMAILS:
		'<div class="title salesforce_v2_contacts_widget_bg">' +
			'<div id="email-dropdown-div-<%=app_name%>" class="view_filters hide"><div class="link_item"><span class="pull-right"><%=resLength%> Results</span><a href class="drop-right nav-trigger" id="active_filter" menuid="#leftViewMenu<%=app_name%>"><%=current_email%></a></div><div class="fd-menu" id="leftViewMenu<%=app_name%>" style="display: none; visibility: visible;"></div></div>'+
			'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
		'</div>',
		CONTACT_SEARCH_RESULTS:
		'<div class="title salesforce_v2_contacts_widget_bg">' +
			'<div id="number-returned"><b> <%=resLength%> results for <%=requester%> </b></div>'+
			'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
		'</div>',
		CONTACT_NA:
		'<div class="title contact-na <%=widget_name%>_bg">' +
			'<div class="name"  id="contact-na">Cannot find <%=reqName%> in <%=app_name%></div>'+
		'</div>',
		CONTACT_TEMPLATE: 
		'<div class="salesforce-widget">' +
			'<div class="clearfix">' +
				'<span class="ellipsis"><span class="tooltip" title="<%=label%>"><%=label%>:</span></span>' +
				'<label class="para-less" id="contact-<%=field%>"><%=value%></label>' +
				'<span class="toggle-para q-para-span hide"><p class="q-marker-more"></p></span>'+
			'</div>' +
		'</div>',
		OPPORTUNITY_SEARCH_RESULTS:
			'<div class="bottom_div mt10 mb10"></div>'+
			'<div class="title salesforce_v2_contacts_widget_bg">' +
				'<div id="opportunities"><b>Opportunities</b></div>'+
				'<%=opportunityCreateLink%>'+
				'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
				'<%=opportunityForm%>'+
			'</div>',
		OPPORTUNITY_SEARCH_RESULTS_NA:
			'<div class="bottom_div mt10 mb10"></div>'+
			'<div class="title contact-na salesforce_v2_contacts_widget_bg">' +
				'<div id="opportunities"><b>Opportunities</b></div>'+
				'<%=opportunityCreateLink%>'+
				'<div class="name"  id="contact-na">No opportunities found for this account</div>'+
				'<%=opportunityForm%>'+
			'</div>',
		ACCOUNT_ENTITY_TEMPLATE: 
				'<div class="salesforce-widget">' +
					'<div class="clearfix">' +
						'<span class="ellipsis"><span class="tooltip" title="<%=label%>"><%=label%>:</span></span>' +
						'<label id="contact-<%=field%>"><a target="_blank" href="<%=external_link%>"><%=value%></a></label>' +
					'</div>' +
				'</div>',
		COMMON_CONTACT_TEMPLATE:
			'<div class="salesforce-widget">' +
						'<div class="clearfix">' +
							'<span class="ellipsis"><span class="tooltip" title="<%=label%>"><%=label%>:</span></span>' +
							'<label class="para-less" id="contact-<%=field%>"><%=value%></label>' +
							'<span class="toggle-para q-para-span hide"><p class="q-marker-more"></p></span>'+
						'</div>'+
			'</div>'
	});
}(window.jQuery));

var UIUtil = {

	constructDropDown:function(data, type, dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm, keepOldEntries,searchAttr) {
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
			entityEmailValue = (!searchAttr) ? parser.getNodeValueStr(entitiesArray[i], "email") :  parser.getNodeValueStr(entitiesArray[i], searchAttr).toLowerCase();
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
				newEntityOption.innerHTML = dispName.escapeHTML();
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
		if(filterKey.indexOf(',')!=(-1)) {
			matching_nodes_data = jQuery(filterKey.replace(/,/ig,' '), dataNode).map(function(i, node){return node.textContent;}).get();
			return matching_nodes_data.include(filterValue);
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

		var parent_form = jQuery("#" + integrationName + context + '-' + fieldName).parentsUntil('form').siblings().addBack();
		
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

	util_loaded: {},

	include_js: function(jslocation) {
		widget_script = document.createElement('script');
		widget_script.type = 'text/javascript';
		widget_script.src = jslocation+"?"+timeStamp;
		document.getElementsByTagName('head')[0].appendChild(widget_script);
	},

	include_util_js: function(jslocation,call_back) {
		if (this.util_loaded[jslocation]) {
			call_back();
			return;
		}
		this.util_loaded[jslocation] = true;
		widget_script = document.createElement('script');
		widget_script.type = 'text/javascript';
		if(widget_script.readyState){ //For IE
			widget_script.onreadystatechange=function(){
				if(widget_script.readyState == "loaded" || widget_script.readyState == "complete"){
					widget_script.onreadystatechange=null;
					call_back();
				}
			};
		}
		else{ //For other browsers
			widget_script.onload=call_back;
		}
		widget_script.src = jslocation+"?"+timeStamp;
		document.getElementsByTagName('head')[0].appendChild(widget_script);
	}
};

CustomWidget.include_js("/assets/strftime-min.js");

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

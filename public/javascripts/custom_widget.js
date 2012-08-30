var Freshdesk = {}

Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		this.app_name = this.options.app_name || "Integrated Application";
		if(!this.options.widget_name) this.options.widget_name = this.app_name.toLowerCase()+"_widget"
		if(!this.options.username) this.options.username = Cookie.retrieve(this.options.widget_name+"_username");
		if(!this.options.password) this.options.password = Cookie.retrieve(this.options.widget_name+"_password") || 'x'; // 'x' is for API key handling.
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

	display:function(){
		var cw = this;
		if(this.options.login_html != null && !(this.options.username && this.options.password)){
			cw.display_login();
		} else {
			if (this.options.application_html){
				this.content_element.innerHTML = (typeof this.options.application_html == "function") ? this.options.application_html() : this.options.application_html;
			}
		}
	},

	call_init_requests: function() {
		if(this.options.init_requests){
			cw=this;
			this.options.init_requests.each(function(reqData){
				if(reqData) cw.request(reqData);
			});
		}
	},

	request:function(reqData){
		reqName = reqData;
		if(typeof reqData == "string") {
			reqData = this.options.requests[reqName];
		}
		reqData.domain = this.options.domain;
		reqData.ssl_enabled = this.options.ssl_enabled;
		reqData.accept_type = reqData.accept_type || reqData.content_type;
		reqData.method = reqData.method || "get";
		reqHeader = {}
		if(this.options.use_server_password) {
			reqData.username = this.options.username
			reqData.use_server_password = this.options.use_server_password
			reqData.app_name = this.options.app_name.toLowerCase()
		}
		else if(this.options.auth_type == 'OAuth'){
			reqHeader = {Authorization:"OAuth " + this.options.oauth_token}
		} 
		else {
			reqHeader = {Authorization:"Basic " + Base64.encode(this.options.username + ":" + this.options.password)}
		}
		new Ajax.Request("/http_request_proxy/fetch",{
      asynchronous: true,
			parameters:reqData,
			requestHeaders:reqHeader,
			onSuccess:function(evt) {
				this.resource_success(evt, reqName, reqData)
			}.bind(this),
			onFailure:function(evt) {
				this.resource_failure(evt, reqData)
			}.bind(this)
		});
	},

	resource_success:function(evt, reqName, reqData) {
		if(reqData != null && reqData.on_success != null){
			reqData.on_success(evt);
		} else {
			resJ = evt.responseJSON;
			if(this.options.parsers != null && this.options.parsers[reqName] != null) resJ = this.options.parsers[reqName](resJ)
			if(this.options.templates != null && this.options.templates[reqName] != null) {
				this.options.application_html = _.template(this.options.templates[reqName], resJ)
				this.options.display();
			}
		}
	},

	resource_failure:function(evt, reqData){
		resJ = evt.responseJSON;
		if (evt.status == 401) {
			this.options.username = null;
			this.options.password = null;
			Cookie.remove(this.options.widget_name + "_username");
			Cookie.remove(this.options.widget_name + "_password");
			if (typeof reqData.on_failure != 'undefined' && reqData.on_failure != null) {
				reqData.on_failure(evt);
			} else if (this.options.auth_type == 'OAuth'){
				cw = this;
				this.refresh_access_token(function(){
					if(cw.options.oauth_token) {
						cw.request(reqData);
					} else {
						cw.alert_failure("Problem in connecting to "+this.app_name+". Please try again later.")
					}
				});
			} else { this.alert_failure("Given user credentials for "+this.app_name+" are incorrect. Please correct them."); }
		}
		else if (evt.status == 403) {
			err_msg = (resJ) ? resJ[0].message : "Request forbidden."
			this.alert_failure(this.app_name+" declined the request. \n\n " + this.app_name + " returns the following error : " + err_msg);
		}
		else if (evt.status == 502) {
			this.alert_failure(this.app_name+" is not responding.  Please verify the given domain.");
		} else if (evt.status == 500) {
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
		} else {
				errorStr = evt.responseText;
				this.alert_failure(this.app_name+" reports the below error: \n\n" + errorStr + "\n\nTry again after correcting the error or fix the error manually.  If you can not do so, contact support.");
		}
	},

	alert_failure:function(errorMsg) {
		if (this.error_element == null || this.error_element == "") {
			alert(errorMsg);
		} else {
			jQuery(this.error_element).removeClass('hide').parent().removeClass('loading-fb');
			this.error_element.innerHTML = errorMsg;
		}
	},

	refresh_access_token:function(callback){
		cw = this;
		this.options.oauth_token = null;
		new Ajax.Request("/integrations/refresh_access_token/"+this.options.app_name.toLowerCase(), {
				asynchronous: true,
				method: "get",
				onSuccess: function(evt){
					resJ = evt.responseJSON;
					cw.options.oauth_token = resJ.access_token;
					if(callback) callback();
				},
				onFailure: function(evt){
					cw.options.oauth_token = null;
					if(callback) callback();
				}
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

	delete_integrated_resource:function(last_fetched_id, resultCallback) {
		if(last_fetched_id != null && last_fetched_id != ""){
			reqData = {
			"integrated_resource[id]":last_fetched_id
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
		
	}
};

Freshdesk.CRMWidget=Class.create();
Freshdesk.CRMWidget.prototype={
	initialize:function(widgetOptions, integratable_impl) {
		Freshdesk.CRMWidget.addMethods(Freshdesk.Widget.prototype); // Extend the Freshdesk.Widget
		if(widgetOptions.domain) {
			if(widgetOptions.reqEmail == ""){
				this.alert_failure('Email not available for this requester. Please make sure a valid Email is set for this requester.');
			} else {
				widgetOptions.integratable_impl = integratable_impl;
				cnt_req = integratable_impl.get_contact_request();
				if(cnt_req) {
					cnt_req.on_success = this.handleContactSuccess.bind(this);
					if (widgetOptions.auth_type != 'OAuth') cnt_req.on_failure = this.handleFailure.bind(this);
					widgetOptions.init_requests = [cnt_req];
				}
				this.initialize(widgetOptions); // This will call the initialize method of Freshdesk.Widget.
			}
		} else {
			this.alert_failure('Domain name not configured. Try reinstalling '+this.options.app_name);
		}
	},

	handleFailure:function(response) {
		this.options.integratable_impl.processFailure(response, this);
	},

	handleContactSuccess:function(response){
		resJson = response.responseJSON;
		this.contacts = this.options.integratable_impl.parse_contact(resJson);
		if (this.contacts.length > 0) {
			if(this.contacts.length == 1){
				this.renderContactWidget(this.contacts[0]);
				jQuery('#search-back').hide();
			} else {
				this.renderSearchResults();
			}
		} else {
			this.renderContactNa();
		}
		jQuery("#"+this.options.widget_name).removeClass('loading-fb');
	},

	renderSearchResults:function(){
		var salesforceResults="";
		for(var i=0; i<this.contacts.length; i++){
			salesforceResults += '<a href="javascript:cw.renderContactWidget(this.contacts[' + i + '])">'+this.contacts[i].name+'</a><br/>';
		}
		var results_number = {resLength: this.contacts.length, requester: this.options.reqEmail, resultsData: salesforceResults};
		this.renderSearchResultsWidget(results_number);
	},

	renderContactWidget:function(eval_params){
		cw=this;
		eval_params.app_name = this.options.app_name;
		this.options.application_html = function(){ return _.template(cw.VIEW_CONTACT, eval_params);	} 
		this.display();
		jQuery("#"+this.options.widget_name+" .contact-type").show();
	},

	renderSearchResultsWidget:function(results_number){
		cw=this;
		this.options.application_html = function(){ return _.template(cw.CONTACT_SEARCH_RESULTS, results_number);} 
		this.display();
	},

	renderContactNa:function(){
		cw=this;
		this.options.application_html = function(){ return _.template(cw.CONTACT_NA, cw.options);} 
		this.display();
	},

	VIEW_CONTACT:
			'<span class="contact-type hide"><%=type%></span>' +
			'<div class="title">' +
				'<div class="salesforce-name">' +
					'<div id="contact-name"><a target="_blank" href="<%=url%>"><%=name%></a></div>' +
				    '<div id="contact-desig"><%=designation%></div>'+
			    '</div>' + 
		    '</div>' + 
		    '<div class="field half_width">' +
		    	'<div id="crm-contact">' +
				    '<label>Contact</label>' +
				    '<span id="contact-address"><%=address%></span>' +
			    '</div>'+	
		    	'<div  id="crm-dept">' +
				    '<label>Department</label>' +
				    '<span id="contact-dept"><%=department%></span>' +
			    '</div>'+	
		    '</div>'+
		    '<div class="field half_width">' +
		    	'<div  id="crm-phone">' +
				    '<label>Phone</label>' +
				    '<span id="contact-phone"><%=phone%></span>'+
			    '</div>' +
				'<div id="crm-mobile">' +
				    '<label>Mobile</label>' +
				    '<span id="contact-mobile"><%=mobile%></span>'+
				'</div>' +
			'</div>'+
			'<div class="external_link"><a id="search-back" href="javascript:cw.renderSearchResults();"> &laquo; Back </a><a target="_blank" id="crm-view" href="<%=url%>">View <span id="crm-contact-type"><%=type%></span> in <%=app_name%></a></div>',

	CONTACT_SEARCH_RESULTS:
		'<div class="title">' +
			'<div id="number-returned" class="salesforce-name"> <%=resLength%> results returned for <%=requester%> </div>'+
			'<div id="search-results"><%=resultsData%></div>'+
		'</div>',

	CONTACT_NA:
		'<div class="title contact-na">' +
			'<div class="salesforce-name"  id="contact-na">Cannot find <%=reqName%> in <%=app_name%></div>'+
		'</div>'
};

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
		widget_script.src = jslocation + "?" + (new Date().getTime());
		document.getElementsByTagName('head')[0].appendChild(widget_script);
	}
};
CustomWidget.include_js("/javascripts/base64.js");
CustomWidget.include_js("/javascripts/frameworks/underscore-min.js");

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
	}
/*
	getNodeAttrValue:function(dataNode, lookupTag, attrName){
		var element = dataNode.getElementsByTagName(lookupTag);
		if(element==null || element.length==0){
			return null;
		}
		return element[0].getAttribute(attrName) || null;
	}*/
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

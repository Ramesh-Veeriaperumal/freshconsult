var Freshdesk = {}

Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		if(!this.options.username) this.options.username = Cookie.retrieve(this.options.anchor+"_username");
		if(!this.options.password) this.options.password = Cookie.retrieve(this.options.anchor+"_password");
		this.content_anchor = $$("#"+this.options.anchor+" .content")[0];
		this.error_anchor = $$("#"+this.options.anchor+" .error")[0];
		this.title_anchor = $$("#"+this.options.anchor+" #title")[0];
		this.app_name = this.options.app_name || "Integrated Application";
		Ajax.Responders.register({
			onException:function(request, ex){
			   //console.log(widget.on_exception(request));
			}
		});
		if(this.options.title){
			this.title_anchor.innerHTML = this.options.title;
		}
		this.display();
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
				Cookie.update(this.options.anchor + "_username", this.options.username);
				Cookie.update(this.options.anchor + "_password", this.options.password);
			}
			this.display();
		}
	},

	logout:function(){
		Cookie.remove(this.options.anchor+"_username"); this.options.username=null;
		Cookie.remove(this.options.anchor+"_password"); this.options.password=null;
		this.display();
	},

	display_login:function(){
		if (this.options.login_content != null) {
			this.content_anchor.innerHTML = this.options.login_content();
		}
	},

	display:function(){
		var cw = this;
		if(this.options.login_content != null && !(this.options.username && this.options.password)){
			this.content_anchor.innerHTML = this.options.login_content();
		} else {
			if (this.options.application_content){
				this.content_anchor.innerHTML = this.options.application_content();	
			}
			if(this.options.application_resources){
			this.options.application_resources.each(
				function(reqData){
					if(reqData) cw.request(reqData);
				});
			}
		}
	},

	request:function(reqData){
		reqData.domain = this.options.domain;
		reqData.ssl_enabled = this.options.ssl_enabled;
		reqData.cache_gets = this.options.cache_gets;
		reqData.accept_type = reqData.accept_type || reqData.content_type;
		reqData.method = reqData.method || "get";
		reqHeader = {}
		if(this.options.use_server_password) {
			reqData.username = this.options.username
			reqData.use_server_password = this.options.use_server_password
			reqData.app_name = this.options.app_name
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
				if(reqData != null && reqData.on_success != null){
					reqData.on_success(evt);
				}
			},
			onFailure:function(evt) {
				
				this.resource_failure(evt, reqData)
			}.bind(this)
		});
	},

	resource_failure:function(evt, reqData){
		resJ = evt.responseJSON;
		if (evt.status == 401) {
			this.options.username = null;
			this.options.password = null;
			Cookie.remove(this.options.anchor + "_username");
			Cookie.remove(this.options.anchor + "_password");
			if (typeof reqData.on_failure != 'undefined' && reqData.on_failure != null) {
				reqData.on_failure(evt);
			} else { this.alert_failure("Given user credentials for "+this.app_name+" are incorrect. Please correct them.");}
		} 
		else if (evt.status == 403) {
			this.alert_failure(this.app_name+" declined the request. \n\n " + this.app_name + " returns the following error : " + resJ[0].message);
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
		if (this.error_anchor == null || this.error_anchor == "") {
			alert(errorMsg);
		} else {
			jQuery(this.error_anchor).removeClass('hide').parent().removeClass('loading-fb');
			this.error_anchor.innerHTML = errorMsg;
		}
	},

	refresh_access_token:function(callback){
		widgetMain = this;
		this.options.oauth_token = null;
		new Ajax.Request("/integrations/refresh_access_token/"+this.options.app_name, {
				asynchronous: true,
				method: "get",
				onSuccess: function(evt){
					resJ = evt.responseJSON;
					widgetMain.options.oauth_token = resJ.access_token;
					if(callback) callback();
				},
				onFailure: function(evt){
					widgetMain.options.oauth_token = null;
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
	},
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

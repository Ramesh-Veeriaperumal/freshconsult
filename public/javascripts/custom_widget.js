var Freshdesk = {}

Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		if(!this.options.username) this.options.username = Cookie.get(this.options.anchor+"_username");
		if(!this.options.password) this.options.password = Cookie.get(this.options.anchor+"_password");
		this.content_anchor = $$("#"+this.options.anchor+" #content")[0];
		this.error_anchor = $$("#"+this.options.anchor+" #error")[0];
		this.title_anchor = $$("#"+this.options.anchor+" #title")[0];
		Ajax.Responders.register({
			onException:function(request, ex){
			   //console.log(widget.on_exception(request));
			}
		});
		if(this.options.title){
			this.title_anchor.innerHTML=this.options.title;
		}
		this.display();
	},

	login:function(credentials){
		this.options.username = credentials.username.value;
		this.options.password = credentials.password.value;
		if(this.options.username.blank() && this.options.password.blank()) {
			this.alert_failure("Please provide Username and password.");
		} else {
			if (credentials.remember_me.value == "true") {
				Cookie.set(this.options.anchor + "_username", this.options.username);
				Cookie.set(this.options.anchor + "_password", this.options.password);
			}
			this.display();
		}
	},

	logout:function(){
		Cookie.erase(this.options.anchor+"_username"); this.options.username=null;
		Cookie.erase(this.options.anchor+"_password"); this.options.password=null;
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
			this.content_anchor.innerHTML = this.options.application_content();
			this.options.application_resources.each(
				function(reqData){
					cw.request(reqData);
				});
		}
	},

<<<<<<< HEAD
	request:function(widget){
		if(widget.resource == null){
			if(widget.on_success != null){
				widget.on_success();
			}
		} else {
			var mt = widget.content_type || "application/json";
			new Ajax.Request("/http_request_proxy/fetch",{
				method: widget.method || "get",
				parameters:{
					domain:this.options.domain,
					ssl_enabled:this.options.ssl_enabled,
					resource:widget.resource,
					content_type:mt,
					cache_gets:this.options.cache_gets
				},
				postBody: widget.body, 
				requestHeaders:{
					Authorization:"Basic " + Base64.encode(this.options.username + ":" + this.options.password)
				},
				onSuccess:function(evt) {
					if(widget != null && widget.on_success != null){
						widget.on_success(evt.responseJSON);
					}
				},
				onFailure:function(evt){
					if(widget != null && widget.on_failure != null){
						widget.on_failure(evt);
					}
					this.resource_failure(evt, this);
				}
			});
		}
	},

	submit_data:function(data){
		//alert("data "+data);
		var params=Form.serialize(data);
		params+="&domain="+this.options.domain+"&ssl_enabled="+this.options.ssl_enabled;
		if(this.options.ticket_id){
			params+="&ticket_id="+this.options.ticket_id;
		}
		if(params.indexOf("content_type=")===0){
			var mt=this.options.content_type||"application/xml";
			params+="&content_type="+mt;
		}

=======
	request:function(reqData){
		reqData.domain = this.options.domain;
		reqData.ssl_enabled = this.options.ssl_enabled;
		reqData.cache_gets = this.options.cache_gets;
		reqData.accept_type = reqData.accept_type || reqData.content_type;
		reqData.method = reqData.method || "get";
>>>>>>> time_tracking
		new Ajax.Request("/http_request_proxy/fetch",{
            asynchronous: true,
			parameters:reqData,
			requestHeaders:{
				Authorization:"Basic " + Base64.encode(this.options.username + ":" + this.options.password)
			},
			onSuccess:function(evt) {
				if(reqData != null && reqData.on_success != null){
					reqData.on_success(evt);
				}
			},
			onFailure:this.resource_failure.bind(this)
		});
	},

	resource_failure:function(evt){
		if (evt.status == 401) {
			this.options.username = null;
			this.options.password = null;
			Cookie.erase(this.options.anchor + "_username");
			Cookie.erase(this.options.anchor + "_password");
			if (this.on_failure != null) {
				reqData.on_failure(evt);
			} else { this.alert_failure("Given user credentials are not correct. Please correct it.");}
		} else if (evt.status == 502) {
			this.alert_failure("Remote application is not responding.  Please check whether given domain url is up.");
		} else if (evt.status == 500) {
			this.alert_failure("Unknown server error. Please contact support@freshdesk.com.");
		} else if (this.on_failure != null) {
			reqData.on_failure(evt);
		} else {
			errorStr = evt.responseText;
			this.alert_failure("An error occured: \n\n" + errorStr + "\nPlease contact support@freshdesk.com for further details.");
		}
	},

	alert_failure:function(errorMsg) {
		if (this.error_anchor == null || this.error_anchor !== "") {
			alert(errorMsg);
		} else {
			this.error_anchor.innerHTML = errorMsg;
		}
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
};

var UIUtil = {
	constructDropDown:function(data, dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm) {
		foundEntity = "";
		dropDownBox = $(dropDownBoxId);
		dropDownBox.innerHTML = "";
		var entitiesArray = XmlUtil.extractEntities(data.responseXML, entityName);
		for(i=0;i<entitiesArray.length;i++) {
			if (filterBy != null && filterBy != '') {
				matched = true;
				for (var filterKey in filterBy) {
					filterValue = filterBy[filterKey];
					actualVal = XmlUtil.getNodeValueStr(entitiesArray[i], filterKey);
					if(filterValue != actualVal) {
						matched = false;
						break;
					}
				}
				if (!matched) continue;
			}

			var newEntityOption = new Element("option");
			entityIdValue = XmlUtil.getNodeValueStr(entitiesArray[i], entityId);
			entityEmailValue = XmlUtil.getNodeValueStr(entitiesArray[i], "email");
			if (searchTerm != null && searchTerm != '') {
				if (entityEmailValue == searchTerm) {
					foundEntity = entitiesArray[i];
					newEntityOption.selected = true;
				} else if (entityIdValue == searchTerm) {
					foundEntity = entitiesArray[i];
					newEntityOption.selected = true;
				}
			}
			dispName = "", sep = "";
			for(d=0;d<dispNames.length;d++) {
				dispName += XmlUtil.getNodeValueStr(entitiesArray[i],dispNames[d]) + sep;
				sep = " ";
			}
			if (dispName.length < 2) dispName = entityEmailValue;

			newEntityOption.value = entityIdValue;
			newEntityOption.innerHTML = dispName;
			dropDownBox.appendChild(newEntityOption);
			if (foundEntity == "") {
				foundEntity = entitiesArray[i];
				newEntityOption.selected = true;
			}
		}
		return foundEntity;
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
		var element = dataNode.getElementsByTagName(lookupTag);
		if(element==null || element.length==0){
			return null;
		}
		childNode = element[0].childNodes[0]
		if(childNode == null){
			return"";
		}
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
	}
}

var ObjectFactory=Class.create({});
ObjectFactory.instHash=new Hash();
ObjectFactory.create=function(object, params){
	instance=new object(params);
	ObjectFactory.instHash.set(params.id, instance);
	return instance;
};

ObjectFactory.get=function(objectId){
	return ObjectFactory.instHash.get(objectId);
};

ObjectFactory.remove=function(objectId){
	return ObjectFactory.instHash.unset(objectId);
};



var Cookie=Class.create({});
Cookie.set = function(cookieId, value, expireDays){
	var expireString="";
	if(expireDate!==undefined){
		var expireDate=new Date();
		expireDate.setTime((24*60*60*1000*parseFloat(expireDays)) + expireDate.getTime());
		expireString="; expires="+expireDate.toGMTString();
	}
	return(document.cookie=escape(cookieId)+"="+escape(value||"") + expireString + "; path=/");
};

Cookie.get = function(cookieId){
	var cookie=document.cookie.match(new RegExp("(^|;)\\s*"+escape(cookieId)+"=([^;\\s]*)"));
	return(cookie?unescape(cookie[2]):null);
};

Cookie.erase = function(cookieId){
	var cookie = Cookie.get(cookieId)||true;
	Cookie.set(cookieId, "", -1);
	return cookie;
};

Cookie.accept = function(){
	if(typeof navigator.cookieEnabled=="boolean"){
		return navigator.cookieEnabled;
	}
	Cookie.set("_test","1");
	return(Cookie.erase("_test")==="1");
};

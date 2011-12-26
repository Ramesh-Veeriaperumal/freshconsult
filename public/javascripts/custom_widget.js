var Freshdesk = {}

Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		if(this.options.username) ;else this.options.username = Cookie.get(this.options.anchor+"_username");
		if(this.options.password) ;else this.options.password = Cookie.get(this.options.anchor+"_password");
		this.content_anchor = $$("#"+this.options.anchor+" #content")[0];
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
			alert("Please provide Username and password.");
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

	request:function(reqData){
		reqData.domain = this.options.domain;
		reqData.ssl_enabled = this.options.ssl_enabled;
		reqData.cache_gets = this.options.cache_gets;
		reqData.accept_type = reqData.accept_type || reqData.content_type;
		reqData.method = reqData.method || "get";
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
			onFailure:function(evt){
				if (reqData != null && reqData.on_failure != null) {
					reqData.on_failure(evt);
				} else {
					this.resource_failure(evt, this);
				}
			}.bind(this)
		});
	},

	resource_failure:function(evt, obj){
		if(evt.status == 401){
			obj.options.username=null;
			obj.options.password=null;
			Cookie.erase(obj.options.anchor+"_username");
			Cookie.erase(obj.options.anchor+"_password");
			alert("Given user credentials are not correct. Please correct it.");
		}else{
			errorStr = evt.responseText;
			alert("An error occured: \n\n"+errorStr+"\nPlease contact support@freshdesk.com for further details.");
		}
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

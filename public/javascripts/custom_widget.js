var Freshdesk = {}

Freshdesk.Widget=Class.create();
Freshdesk.Widget.prototype={
	initialize:function(widgetOptions){
		this.options = widgetOptions || {};
		this.options.username = widgetOptions.username || Cookie.get(this.options.anchor+"_username");
		this.options.password = widgetOptions.password || Cookie.get(this.options.anchor+"_password");
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
		this.options.username=credentials.username.value;
		this.options.password=credentials.password.value;
		if(this.options.username.blank()&&this.options.password.blank()){
			//alert("Please provide username and password.");
		}else{
			Cookie.set(this.options.anchor+"_username",this.options.username);
			Cookie.set(this.options.anchor+"_password",this.options.password);
			this.display();
		}
	},

	logout:function(){
		Cookie.erase(this.options.anchor+"_username"); this.options.username=null;
		Cookie.erase(this.options.anchor+"_password"); this.options.password=null;
		this.display();
	},

	display:function(){
		var cw=this;
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
		var mt = reqData.content_type || "application/json";
		new Ajax.Request("/http_request_proxy/fetch",{
			method: reqData.method || "get",
			parameters:{
				domain:this.options.domain,
				ssl_enabled:this.options.ssl_enabled,
				resource:reqData.resource,
				content_type:mt,
				cache_gets:this.options.cache_gets,
				body:reqData.body
			},
			requestHeaders:{
				Authorization:"Basic " + Base64.encode(this.options.username + ":" + this.options.password)
			},
			onSuccess:function(evt) {
				if(reqData != null && reqData.on_success != null){
					reqData.on_success(evt);
				}
			},
			onFailure:function(evt){
				if(reqData != null && reqData.on_failure != null){
					reqData.on_failure(evt);
				}
				this.resource_failure(evt, this);
			}
		});
	},

	resource_failure:function(evt, obj){
		if(evt.status==401){
			obj.options.username=null;
			obj.options.password=null;
			Cookie.erase(obj.options.anchor+"_username");
			Cookie.erase(obj.options.anchor+"_password");
			if(obj.content_anchor.innerHTML != obj.options.login_content()){
				//alert("Username and password are not correct. Please re-enter.");
			}
			obj.display();
		}else{
			//alert(c.responseJSON.error);
		}
	}
};


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
	getNodeValue:function(dataNode, lookupTag){
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

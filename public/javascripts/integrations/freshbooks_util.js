var FreshbooksUtility = Class.create();
FreshbooksUtility.prototype = {
	
	CLIENT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="client.list"> <page>#{page}</page><per_page>100</per_page><folder>active</folder></request>'),
	initialize:function(freshbooksBundle){
		var $this = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		init_reqs = [];
		$this.call_backs = [];
		$this.current_callback = freshbooksBundle.call_back;
		$this.widgetname = freshbooksBundle.widgetname;
		jQuery("#"+$this.widgetname+" .error").bind('DOMSubtreeModified propertychange',function(){
        	if($this.secondary_widget != undefined){
        		$this.handleError();
        	}
		});
		var freshbooksOptions={};

		$this.clients={};
		$this.client_page=0;
		if(freshbooksBundle.reqCompany){
			$this.reqCompany = freshbooksBundle.reqCompany.toLowerCase();
			$this.client_filter="organization";
		}
		else if(freshbooksBundle.reqEmail){
			$this.client_filter="email";
		}
		else{
			$this.client_filter="";
		}
		init_reqs.push({
			body: $this.CLIENT_LIST_REQ.evaluate({page:1}),
			content_type: "application/xml",
			method: "post", 
			on_success: $this.loadFreshbooksClients.bind(this)
		}
		);
		freshbooksOptions.app_name ="freshbooks";
		freshbooksOptions.widget_name=$this.widgetname;
		freshbooksOptions.use_server_password=true;
		freshbooksOptions.auth_type="NoAuth";
		freshbooksOptions.ssl_enabled=true;
		freshbooksOptions.domain = freshbooksBundle.domain;
		freshbooksOptions.init_requests=init_reqs;

        $this.freshdeskWidget = new Freshdesk.Widget(freshbooksOptions);

		$this.request_status="Requested";
	},


	handleRequest:function(call_back,widget_name){
		var $this = this;
        var status = $this.request_status;
        if(widget_name != $this.widgetname){
        	$this.secondary_widget = widget_name;
        }
        if((status == "Requested" || status == "Requesting") && jQuery("#"+$this.widgetname+" .error").html()){
        	$this.handleError();
        }
        else if( status == "Requested" || status == "Requesting" ){
           	$this.call_backs.push(call_back);
        }
        else if(status == "Completed"){
           $this.call_backs.push(call_back);
           $this.loadFreshbookContact($this.call_backs);
           $this.call_backs=[];
        }
	},

	loadClientDetails:function(client_list_response){
		var $this = this;
		jQuery.each(client_list_response,function(index,clientNode){
			var keys=[];
			keys.push(XmlUtil.getNodeValue(clientNode,$this.client_filter));
			if($this.client_filter == "organization"){
				keys[0] = keys[0].toLowerCase();
				keys.push(XmlUtil.getNodeValue(clientNode,"email"));
			}
			for(var i=0;i<keys.length;i++){
				if($this.clients[keys[i]]){
					client_value=$this.clients[keys[i]];
					if(client_value instanceof Array){
						$this.clients[keys[i]].push(clientNode);
					}
					else{
						$this.clients[keys[i]]=[client_value,clientNode];
					}
				}
				else{
					$this.clients[keys[i]]=clientNode;
				}
			}
		});
	},

	loadFreshbooksClients:function(resData){
		var $this = this;
		$this.client_page++;
		var client_list_response=XmlUtil.extractEntities(resData.responseXML,"client");
		$this.loadClientDetails(client_list_response);
		total_pages = $this.fetchMultiPages(resData,"clients",$this.CLIENT_LIST_REQ,$this.loadFreshbooksClients);
		if($this.curr_page == $this.tot_pages && $this.client_page == $this.tot_pages){
			$this.request_status="Completed";
			$this.handleRequest($this.current_callback,$this.widgetname);
		}
		else{
			$this.request_status="Requesting";
		}
	},


	loadFreshbookContact:function(call_backs){
		var $this = this;
		var result=[];
		if($this.client_filter == "organization"){
			if($this.clients[$this.reqCompany] instanceof Array){
				result=$this.clients[$this.reqCompany];
				if(freshbooksBundle.reqEmail){
					var duplicateClients=[];
					for(var i=0;i<$this.clients[$this.reqCompany].length;i++){
						if(freshbooksBundle.reqEmail == XmlUtil.getNodeValue($this.clients[$this.reqCompany][i],"email")){
							duplicateClients.push($this.clients[$this.reqCompany][i]);

						}
					}
					if(duplicateClients.length >1){
						result=duplicateClients;
					}
					else if(duplicateClients.length == 1){
						result=duplicateClients[0];
					}

				}
			}
			else if($this.clients[$this.reqCompany] == undefined){
				result=$this.clients[freshbooksBundle.reqEmail];
			}
			else{
				result=$this.clients[$this.reqCompany];
			}
		}
		else if($this.client_filter == "email"){
			result=$this.clients[freshbooksBundle.reqEmail]; 
		}
		else {
			result="";
		}
		$this.results=result;
		for(var i=0;i<call_backs.length;i++){
        	call_backs[i]();
		}
	},


	fetchMultiPages: function(resData, dataNodeName, reqTemplate, success_fun) {
		tot_pages = 1
		try {
			dataNode = XmlUtil.extractEntities(resData.responseXML, dataNodeName)[0];
			curr_page = dataNode.getAttribute("page");
			tot_pages = dataNode.getAttribute("pages");
			this.tot_items = dataNode.getAttribute("total");
			this.curr_page = curr_page; this.tot_pages = tot_pages;
			if (tot_pages > 1 && curr_page == 1) {
				for (var p = 2; p <= tot_pages; p++) {
					this.freshdeskWidget.request({
						body: reqTemplate.evaluate({page:p}),
						content_type: "application/xml",
						method: "post",
						on_success: success_fun.bind(this)
					});
				}
			}
		}catch(e) {}

		return tot_pages;
	},

	handleError: function(){
		var $this = this;	
		error_html=jQuery("#"+$this.widgetname+" .error").html();
	    jQuery("#" + $this.secondary_widget).removeClass('sloading loading-small');
	    jQuery("#freshbooks_loading").remove();
	    jQuery("#"+$this.secondary_widget+" .error").removeClass('hide').html(error_html);
	}
};

jQuery(document).on('pjax:beforeReplace', function(e) {
Freshdesk.NativeIntegration.freshbooksUtility = undefined;
});
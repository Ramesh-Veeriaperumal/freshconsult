var FreshbooksContactWidget = Class.create();
FreshbooksContactWidget.prototype = {
	
	VIEW_CONTACT:
	'<div class="title <%=widget_name%>_bg">' +
	'<div class="row-fluid">' +
	'<div id="client-name" class="span8">'+
	'<a title="<%=name%>" target="_blank" href="<%=url%>" class="client-title"><%=name%></a></div>' +
	'</div></div>'+
	'<div class="client_details"><%= client_information%></div>'+
	'<div class="field bottom_div"></div>'+
	'<div class="external_link"><a id="search-back" href="#" class="search-back <%=(count>1 ? "": "hide")%>">&laquo; Back</a></div>',


	CONTACT_SEARCH_RESULTS:
	'<div class="title <%=widget_name%>_bg">' +
	'<div id="number-returned"><b> <%=resLength%> results for <%=requester%> </b></div>'+
	'<div id="search-results"><ul id="contacts-search-results"><%=resultsData%></ul></div>'+
	'</div>',

	CONTACT_NA:
	'<div class="title contact-na <%=widget_name%>_bg">' +
	'<div class="name"  id="contact-na">Cannot find <%=reqName%> in <%=app_name%></div>'+
	'</div>',


	initialize:function(freshbooksBundle){
		var $this = this;
		var freshbooksUtility = Freshdesk.NativeIntegration.freshbooksUtility;
		freshbooksBundle.freshbooksNote = jQuery('#freshbooks-note').html();
		freshbooksBundle.widgetname="freshbooks_contacts_widget";

		jQuery("#freshbooks_contacts_widget").addClass("sloading loading-small");

		if(typeof(freshbooksUtility) != 'undefined'){
             freshbooksUtility.handleRequest(function(){ $this.loadFreshbookContacts($this) },"freshbooks_contacts_widget");
		}
		else{
			freshbooksBundle.call_back = function(){ $this.loadFreshbookContacts($this) };
			Freshdesk.NativeIntegration.freshbooksUtility = new FreshbooksUtility(freshbooksBundle);
		}
	},


	loadFreshbookContacts:function($this){
		var $this = $this;
		var freshbooksUtility = Freshdesk.NativeIntegration.freshbooksUtility;
		var result=freshbooksUtility.results;
		$this.results=result;
		if(result instanceof Array && freshbooksUtility.client_filter != ""){
			$this.renderSearchResults(result);
		}
		else if(result == "" || result == undefined){
			$this.renderContactNa();
		}
		else{
			$this.renderContactWidget(result);
		}
	},

	getTemplate:function(result,reqDetails){
		var template="";
		var separator;
		Object.keys(reqDetails).forEach(function(key){
			var value="";
			if(reqDetails[key] instanceof Array){
				template +='<div class="field">' +
				'<div>'+'<label>'+(key.substring(0,1).toUpperCase()+key.substring(1))+':</label>';
				
				if(key =="address"){
					separator=", ";
				}
				else{
					separator=" ";
				}
				for(var i=0;i<reqDetails[key].length;i++){
					var suffix=(i==reqDetails[key].length-1)?"":separator;
					var addressElement = XmlUtil.getNodeValue(result,reqDetails[key][i]);
					if(addressElement){
						value+= addressElement+""+suffix;	
					}
				}
				value = value.trim().replace(/,$/,'');
				if (value) {
					value = value.escapeHTML();
				}
				template +='<span>'+value+'</span>'+
				'</div></div>';
			}
			else{
				value=XmlUtil.getNodeValue(result,reqDetails[key]);
				if (value) {
					value = value.escapeHTML();
				}
				template+= '<div class="field">' +
				'<div>' +
				'<label>'+(key.substring(0,1).toUpperCase()+key.substring(1))+':</label>' +
				'<span>'+value+'</span>' +
				'</div></div>';	
			}
		});
		return template;
	},


	renderContactWidget:function(result,reqDetails){
		var $this = this;
		var reqDetails={name:["first_name","last_name"],email:"email",address:["p_street1","p_street2","p_city","p_state","p_country","p_code"],phone:"work_phone"};
		var reqParams={};
		reqParams.name=XmlUtil.getNodeValue(result,"organization").escapeHTML();
		reqParams.url=XmlUtil.getNodeValue(result,"auth_url");
		reqParams.count=$this.results.length;
		reqParams.widget_name="freshbooks";
		var client_details_template="";
		client_details_template=$this.getTemplate(result,reqDetails);
		reqParams.client_information=client_details_template;
		jQuery("#freshbooks_contacts_widget").removeClass("sloading loading-small");
		jQuery('#freshbooks_contacts_widget .content').html(_.template($this.VIEW_CONTACT,reqParams));
		jQuery('#freshbooks_contacts_widget .content').on('click','#search-back', (function(ev){
			ev.preventDefault();
			$this.renderSearchResults($this.results);
		}));
	},

	renderSearchResults:function(results){
		var $this = this;
		var freshbooksUtility = Freshdesk.NativeIntegration.freshbooksUtility;
		var searchResults="";
		var contacts=(freshbooksUtility.client_filter=="email")?(freshbooksBundle.reqEmail):(freshbooksBundle.reqCompany);
		for(var i=0;i<results.length;i++){
			var client_name=XmlUtil.getNodeValue(results[i],"organization").escapeHTML();
			searchResults += '<li><a class="multiple-contacts" href="#" data-client="' + i + '">'+client_name+'</a></li>';
		}
		var results_number = {resLength: results.length, requester: contacts, resultsData: searchResults,widget_name:"freshbooks"};
		jQuery("#freshbooks_contacts_widget").removeClass("sloading loading-small");
		jQuery('#freshbooks_contacts_widget .content').html(_.template($this.CONTACT_SEARCH_RESULTS,results_number));
		jQuery('#freshbooks_contacts_widget .content').on('click','.multiple-contacts', (function(ev){
			ev.preventDefault();
			$this.renderContactWidget(results[jQuery(this).data('client')]);
		}));
	},

	renderContactNa:function(){
		var $this = this;
		var reqParams={};
		reqParams.widget_name="freshbooks";
		reqParams.app_name="freshbooks";
		reqParams.reqName=freshbooksBundle.reqName;
		jQuery("#freshbooks_contacts_widget").removeClass("sloading loading-small");
		jQuery('#freshbooks_contacts_widget .content').html(_.template($this.CONTACT_NA,reqParams));
	}

}

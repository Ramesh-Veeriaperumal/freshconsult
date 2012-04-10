var JiraWidget = Class.create();
JiraWidget.prototype= {
	JIRA_FORM:new Template(
		'<div id="jira_issue_forms"><div id="jira_issue_create"><div class="heading"><span class="current_form">Create a new issue</span>' +
			'<span class="divider"> or </span>' + 
			' <span class="other_form show_linkform">Link to an existing issue</span></div>' + 
	    '<form id="jira-add-form" method="post" class="ui-form"> ' +
		    '<div class="field half_width left">' +
			    '<label>Project</label> ' +
			    '<select class="full hide" name="project_id" id="jira-projects" onchange="jiraWidget.projectChanged(this.options[this.selectedIndex].value)"></select> ' +
			    '<div class="loading-fb" id="jira-projects-spinner"> </div>' + 
		    '</div>' + 
		    '<div class="field half_width right">' +
			    '<label>Issue Type</label> ' +
			    '<select class="full hide" name="issue_type" id="jira-issue-types" onchange="jiraWidget.typeChanged(this.options[this.selectedIndex].value)"></select> ' +
			    '<div class="loading-fb" id="jira-issue-types-spinner"> </div>' + 
		    '</div>' + 
		    '<div class="field">' +
			    '<label>Summary</label> ' +
			    '<input type="text" name="issue_summary" id="jira-issue-summary" class="full" value="#{subject}" />' +
	   	    '</div>' + 
	   	    '<input type="submit" id="jira-submit" class="uiButton"  value="Create Issue" ' +
	   	    'onclick="jiraWidget.createJiraIssue();return false;" disabled> ' +
	    '</form></div>' +
	    '<div id="jira_issue_link" class="hide"> ' +
	    '<div class="heading"><span class="other_form show_createform">Create a new issue</span>' +
			'<span class="divider"> or </span>' + 
			' <span class="current_form ">Link to an existing issue</span></div>' + 
   		'<form id="jira-link-issue" class="ui-form"> ' +
		    '<div class="field">' +
				'<label>Issue ID</label>'+
				'<label for="jira-issue-id" class="overlabel">Ex: FX-173</label>' +
				'<input type="text" id="jira-issue-id" class="full"></input>' +
			'</div>' +
			'<input type="submit" id="jira-submit" class="uiButton" value="Link Issue" ' +
			'onclick="jiraWidget.linkJiraIssue();return false;"> '+
   	    '</form></div></div>'
		),
	JIRA_ISSUE:new Template(
		'<div id="jira-issue-widget">' +
		'<form id="jira-issue-form" method="post"> ' +
	    '<div class="jira_issue_details hide"><div id="jira-link"><span id="jira-issue-id"></span><br />'+
	    '<span id="jira-issue-summary"></span>'+
	    '<a target="_blank" id="jira-view">View issue in Jira</a></div>'+
	    '<ul>'+
	    '<li> <label>Type</label>' +
	    '<span id="jira-issue-type"></span>'+
	    '</li>'+
	    '<li> <label>Status</label>' +
	    '<span id="jira-issue-status"></span>'+
	    '</li>'+
	    '<li> <label>Created On</label>' +
	    '<span id="jira-issue-createdon"></span>'+
	    '</li>'+
	    '<li> <label class="hide" id="jira-link-label">Linked Freshdesk Tickets</label> <br />' +
	    '<span id="jira-issue-link"></span>'+
	    '</li>'+
	    '<a id="jira-unlink" class="uiButton" title="Remove the link between this ticket and the associated Jira issue" > Unlink Issue </a>' +
   	    '<a id="jira-delete" class="uiButton" title="Delete the associated issue in Jira "> Delete Issue </a>' +
	    '</div>'+
	    '</form></div>'),
   	JIRA_PARENT:new Template(
   		'<script type="text/javascript>jiraWidget.displayCreateWidget();</script>'),
   	JIRA_LINK:new Template(
   		'<div class="heading"><span class="other_form show_createform">Create a new issue</span>' +
			'<span class="divider"> or </span>' + 
			' <span class="current_form ">Link to an existing issue</span></div>' + 
   		'<form id="jira-link-issue" class="ui-form"> ' +
		    '<div class="field">' +
		'<label>Issue ID</label>'+
		'<input type="text" id="jira-issue-id" class="full"></input>' +
		'</div>' +
		'<input type="submit" id="jira-submit" class="uiButton" style="margin-top: 1px;" value="Link Issue" ' +
		'onclick="jiraWidget.linkJiraIssue();return false;"> '+
		'<input type="submit" id="jira-cancel" class="uiButton" style="margin-top: 1px;" value="Cancel" ' +
   	    'onclick="jiraWidget.displayParentWidget();return false;"> ' +
   	    '</form>'),

	initialize:function(jiraBundle){
		jiraWidget = this; // Assigning to some variable so that it can be accessible inside custom_widget.
		this.projectData = "";
		var init_reqs = [];
		if(jiraBundle.remote_integratable_id)
		{
			init_reqs = [{
				resource: "rest/api/latest/issue/" + jiraBundle.remote_integratable_id,
				content_type: "application/json",
				on_failure: jiraWidget.processFailure,
				on_success: jiraWidget.displayIssue.bind(this)
			}];	
		}  else {
			init_reqs = [{
				resource: "rest/api/latest/project",
				content_type: "application/json",
				on_success: jiraWidget.loadProject.bind(this),
				on_failure: jiraWidget.processFailure.bind(this)
			}];

			jQuery('#jira_issue_loading').addClass('hide');
		} 
		if(jiraBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				app_name:"Jira",
				anchor:"jira_widget",
				domain:jiraBundle.domain,
				application_id:jiraBundle.application_id,
				username:jiraBundle.username, 
				use_server_password: true,
				login_content: null,
				application_content: function(){
					if (jiraBundle.remote_integratable_id) {
						return jiraWidget.JIRA_ISSUE.evaluate({});
					} else {
						return jiraWidget.JIRA_FORM.evaluate({subject:jiraBundle.ticketSubject});
					}
				},
				application_resources:init_reqs
			});
		}

		jQuery('.show_linkform, .show_createform').live('click',function(e) {
			e.preventDefault();
			jQuery('#jira_issue_create, #jira_issue_link').toggleClass('hide');
		});

		jQuery('#jira-unlink').live('click',function(ev) {
			ev.preventDefault();
			jiraWidget.unlinkJiraIssue();
		});

		jQuery('#jira-delete').live('click',function(ev) {
			ev.preventDefault();
			jiraWidget.deleteJiraIssue();
		});

	},	

	loadProject:function(resData) {
		this.projectData=resData;
		this.handleLoadProject(resData);
		this.loadIssueTypes();
	},

	projectChanged:function(project_id) {
		Cookie.update("jira_project_id", project_id);
	},

	handleLoadProject:function() {
		selectedProjectNode = UIUtil.constructDropDown(this.projectData, "json", "jira-projects", null, "key", ["name"], null, Cookie.retrieve("jira_project_id")||"");
		UIUtil.hideLoading('jira','projects','');
	},

	loadIssueTypes:function(){
		
		reqData = {
				"domain":jiraBundle.domain
			};
			new Ajax.Request("/integrations/jira_issue/get_issue_types", {
				asynchronous: true,
				method: "get",
				parameters: reqData,
				onSuccess: function(evt){
					resJ = evt.responseJSON
					if (resJ['error'] == null || resJ['error'] == "") {
						resData = evt;
						this.handleLoadIssueTypes(resData);
					} else {
						jiraException = this.jiraExceptionFilter(resJ['error'])
						if(jiraException == false)
						alert("Unknown server error. Please contact support@freshdesk.com.");
					}
					if (resultCallback) 
						resultCallback(evt);
				}.bind(this),
				onFailure: function(evt){
					
					var error_message = jQuery(evt.responseText).find('pre').first().text();
					
					if (resultCallback) 
						resultCallback(evt);
				}
			});
			
	},

	typeChanged:function(type_id){
		//alert("Issue Type ID : " + type_id);
		Cookie.update("jira_type_id", type_id);
	},

	handleLoadIssueTypes:function(resData){
		selectedProjectNode = UIUtil.constructDropDown(resData, "json", "jira-issue-types", "types", "typeId", ["typeName"], null, Cookie.retrieve("jira_type_id")||"");
		UIUtil.hideLoading('jira','issue-types','');
	},

	getCurrentUrl:function(){
		current_url = document.URL;
		domain_url = current_url.split("helpdesk/tickets");
		ticket_url = domain_url[0] + "helpdesk/tickets" + "/" + jiraBundle.ticketId;
		return ticket_url; 
	},

	createJiraIssue:function(resultCallback) {

		this.showSpinner();

		self = this;
		integratable_type = "issue-tracking";
		summary = jQuery('#jira-issue-summary').val();
		projectId = (jiraBundle.projectId) ? jiraBundle.projectId : jQuery('#jira-projects').val();
		typeId = (jiraBundle.typeId) ? jiraBundle.typeId : jQuery('#jira-issue-types').val();
		ticketSummary = (summary) ? summary : jiraBundle.ticketSubject;
		//ticketData = "Freshdesk Ticket #"+jiraBundle.ticketId+" -- " + document.URL;
		ticketData = "#"+jiraBundle.ticketId+" (" + jiraWidget.getCurrentUrl() +") - " + jiraBundle.ticketSubject;
		reqData = {
				"domain":jiraBundle.domain,
				"projectId": projectId,
				"issueTypeId":typeId,
				"summary":ticketSummary,
				"description":jiraBundle.jiraNote,
				"application_id": jiraBundle.application_id,
				"ticketData":ticketData,
				"integrated_resource[local_integratable_id]":jiraBundle.ticket_rawId,
				"integrated_resource[local_integratable_type]": integratable_type

			};
			new Ajax.Request("/integrations/jira_issue/create", {
				asynchronous: true,
				method: "post",
				parameters: reqData,
				onSuccess: function(evt){
					resJ = evt.responseJSON
					if (resJ['error'] == null || resJ['error'] == "") {
					jiraBundle.integrated_resource_id = resJ['integrated_resource']['id'];
					jiraBundle.remote_integratable_id = resJ['integrated_resource']['remote_integratable_id'];
					jiraBundle.custom_field_id = resJ['integrated_resource']['custom_field'];
					jiraWidget.renderDisplayIssueWidget();
				}
				else{
					jiraException = self.jiraExceptionFilter(resJ['error'])
					if(jiraException == false)
					alert("Unknown server error. Please contact support@freshdesk.com.");
				}

					jQuery('#jira_issue_icon a.jira').removeClass('jira').addClass('jira_active');
					if (resultCallback) 
						resultCallback(evt);
				},
				onFailure: function(evt){
					if (resultCallback) 
						resultCallback(evt);
				}
			});
	},

	jiraExceptionFilter:function(errMsg){
		if (errMsg.indexOf("Exception:") != -1){
			jiraMsg = errMsg.split("Exception:")
			alert("Jira reports the below error:\n\n" + jiraMsg[1] +"\n\n Please contact Support.");
			return true;
		}
		else
		return false;
	},

	displayIssue:function(resData){
		resJson = resData.responseJSON;
		var value="";
		var issueLink = jiraBundle.domain + "/browse/" + jiraBundle.remote_integratable_id;
		jiraVer = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype.value.name");
		if(jiraVer != ""){
			value = ".value";
		}
		fieldName = "fields.issuetype"+value+".name"
		var issueType = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype"+value+".name");

		var issueSummary = JsonUtil.getMultiNodeValue(resJson, "fields.summary"+value);
		var issueStatus = JsonUtil.getMultiNodeValue(resJson, "fields.status"+value+".name");
		var issueCreated = JsonUtil.getMultiNodeValue(resJson, "fields.created"+value);
		if(jiraBundle.custom_field_id){
		this.displayCustomFieldData(resJson, value);
		}
		if(issueStatus == "Resolved" || issueStatus == "Closed")
			issueIdHtml = "<a class='strikethrough' target='_blank' href='" + issueLink + "'>" + jiraBundle.remote_integratable_id +"</a>";
		else
			issueIdHtml = "<a target='_blank' href='" + issueLink + "'>" + jiraBundle.remote_integratable_id +"</a>";
		jQuery('#jira-issue-id').html(issueIdHtml) ;
		jQuery('#jira-view').attr("href",issueLink);
		jQuery('#jira-issue-type').text(issueType);
		jQuery('#jira-issue-summary').html(issueSummary);
		jQuery('#jira-issue-status').text(issueStatus);
		jQuery('#jira-issue-createdon').text(freshdate(issueCreated));
		this.displayIssueWidgetStatus = false;
		this.hideSpinner();


		jQuery('#jira_issue_loading').addClass('hide');
		jQuery('.jira_issue_details').removeClass('hide');	

	},

	formatIssueLinks:function(issueLinks){
		jiraIssues = issueLinks.split("\n");
		jiraWidget.ticketData = issueLinks;
		jiraWidget.unlinkId = jiraBundle.remote_integratable_id;
		var issueHtml="";
		for(var i=0; i<jiraIssues.length; i++){
			startUrl = jiraIssues[i].indexOf('(');
			endUrl = jiraIssues[i].indexOf(')');
			if(startUrl != null && endUrl != null){
				ticketUrl = jiraIssues[i].slice(startUrl + 1, endUrl);
			}
			if(ticketUrl){
				ticket = jiraIssues[i].split(" - ");
				ticketMain = ticket[0].split(" (");
				issueHtml += "<a target='_blank' href='" + ticketUrl + "'>" + ticketMain[0] +" - " + ticket[1] +"</a><br/>";	
			}
			
		}
		return issueHtml;
	},

	renderDisplayIssueWidget:function(){
		init_reqs = [{
				resource: "rest/api/latest/issue/" + jiraBundle.remote_integratable_id,
				content_type: "application/json",
				on_failure: jiraWidget.processFailure,
				on_success: jiraWidget.displayIssue.bind(this)
			}];		
		jiraWidget.freshdeskWidget.options.application_content = this.displayIssueContent 
		jiraWidget.freshdeskWidget.options.application_resources = init_reqs;
		jiraWidget.freshdeskWidget.display();

		//Show loading
		this.showSpinner();
		
	},

	displayCreateWidget:function(){
		this.hideSpinner();
		init_reqs = [{
				resource: "rest/api/latest/project",
				content_type: "application/json",
				on_failure: jiraWidget.processFailure,
				on_success: jiraWidget.loadProject.bind(this)
			}];
		jiraWidget.freshdeskWidget.options.application_content = this.displayFormContent;
		jiraWidget.freshdeskWidget.options.application_resources = init_reqs;
		jiraWidget.freshdeskWidget.display();
		
		jQuery('#jira-issue-summary').val(jiraBundle.ticketSubject);

		
	},

	displayLinkWidget:function(){
		jiraWidget.freshdeskWidget.options.application_content = this.displayLinkContent;
		jiraWidget.freshdeskWidget.options.application_resources = null;
		jiraWidget.freshdeskWidget.display();

	},

	displayParentWidget:function(){

		jiraWidget.freshdeskWidget.options.application_content = this.displayParentContent;
		jiraWidget.freshdeskWidget.options.application_resources = null;
		jiraWidget.freshdeskWidget.display();
	},

	displayIssueContent:function(){
		return jiraWidget.JIRA_ISSUE.evaluate({});
	},

	displayFormContent:function(){
		return jiraWidget.JIRA_FORM.evaluate({});
	},

	displayLinkContent:function(){
		return jiraWidget.JIRA_LINK.evaluate({});	
	},

	displayParentContent:function(){
		return jiraWidget.JIRA_FORM.evaluate({});
	},


	linkJiraIssue:function(){
		this.showSpinner();
		
		remoteKey = jQuery('#jira-issue-id').val();
		jiraWidget.linkIssueId = remoteKey;
		jiraWidget.linkedTicket=""
		this.freshdeskWidget.request({
				resource: "rest/api/latest/issue/"+encodeURIComponent(remoteKey),
				content_type: "application/json",
				on_success: jiraWidget.updateIssue.bind(this),
				on_failure: jiraWidget.processFailure
			});
	},

	updateIssue:function(resData){
		self = this;
		var isCustomFieldDef = false;
		var freshdeskData;
		integratable_type = "issue-tracking";
		if(resData)
		freshdeskData = this.getCustomFieldData(resData.responseJSON);

		if (freshdeskData != null)
		{
			if (freshdeskData.indexOf(jiraWidget.getCurrentUrl()) != -1)
			ticketData = freshdeskData;
			else{
				isCustomFieldDef = true;
				if (freshdeskData == "undefined" || freshdeskData == "")
					ticketData = "#"+jiraBundle.ticketId+" (" + jiraWidget.getCurrentUrl() +") - " + jiraBundle.ticketSubject;
				else
					ticketData = freshdeskData + "\n#"+jiraBundle.ticketId+" (" + jiraWidget.getCurrentUrl() +") - " + jiraBundle.ticketSubject;
			}
				reqData = {
				"domain":jiraBundle.domain,	
				"isCustomFieldDef":"true",
				"customFieldId":jiraBundle.custom_field_id,
				"ticketData":ticketData,
				"remoteKey":jiraWidget.linkIssueId,
				"application_id": jiraBundle.application_id,
				"integrated_resource[local_integratable_id]":jiraBundle.ticket_rawId,
				"integrated_resource[local_integratable_type]": integratable_type
			};	
		}
		else
		{
			ticketData = "#"+jiraBundle.ticketId+" (" + jiraWidget.getCurrentUrl() +") - " + jiraBundle.ticketSubject;
			reqData = {
				"domain":jiraBundle.domain,
				"remoteKey":jiraWidget.linkIssueId,
				"ticketData":ticketData,
				"isCustomFieldDef":"false",	
				"application_id": jiraBundle.application_id,
				"integrated_resource[local_integratable_id]":jiraBundle.ticket_rawId,
				"integrated_resource[local_integratable_type]": integratable_type
			};
		}

		new Ajax.Request("/integrations/jira_issue/update", {
				asynchronous: true,
				method: "put",
				parameters: reqData,
				onSuccess: function(evt){
					
					resJ = evt.responseJSON
					displayIssue = true;
					if (resJ['error'] == null || resJ['error'] == "") {
						jiraBundle.integrated_resource_id = resJ['integrated_resource']['id'];
						jiraBundle.remote_integratable_id = resJ['integrated_resource']['remote_integratable_id'];
						jiraWidget.linkIssue = true;
						jiraBundle.custom_field_id = resJ['integrated_resource']['custom_field'];

						jQuery('#jira_issue_icon a.jira').removeClass('jira').addClass('jira_active');
						jiraWidget.renderDisplayIssueWidget();
					}
					else{
						jiraException = self.jiraExceptionFilter(resJ['error'])
						if(jiraException == false)
						alert("Unknown server error. Please contact support@freshdesk.com.");
					}

					if (resultCallback) 
						resultCallback(evt);
				},
				onFailure: function(evt){
					if (resultCallback) 
						resultCallback(evt);
				}
		});
			
	},

	unlinkJiraIssue:function(){
		if (jiraBundle.integrated_resource_id) {
			this.showSpinner();
			if(jiraWidget.ticketData){
				linkedTicket = "#"+jiraBundle.ticketId+" (" + jiraWidget.getCurrentUrl() +") - " + jiraBundle.ticketSubject;
				ticketData = "";
				fdTickets = jiraWidget.ticketData.split("\n");
				for (var i=0; i < fdTickets.length; i++){
					if (fdTickets[i].trim() != '' && fdTickets[i] != linkedTicket) {
						ticketData += fdTickets[i] + "\n";
					}
				}
				reqData = {
				"domain":jiraBundle.domain,
				"remoteKey":jiraWidget.unlinkId,
				"ticketData":ticketData,
				"application_id": jiraBundle.application_id,
				"integrated_resource[id]":jiraBundle.integrated_resource_id
				}; 
			}
			new Ajax.Request("/integrations/jira_issue/unlink", {
				asynchronous: true,
				method: "put",
				parameters: reqData,
				onSuccess: function(evt){					
					resJ = evt.responseJSON
					if (resJ['error'] == null || resJ['error'] == "") {
						
					}
					else{
						jiraException = self.jiraExceptionFilter(resJ['error'])
						if(jiraException == false)
						alert("Unknown server error. Please contact support@freshdesk.com.");
					}
					if (resultCallback) 
						resultCallback(evt);
				},
				onFailure: function(evt){
					if (resultCallback) 
						resultCallback(evt);
				}
			});
			jiraBundle.integrated_resource_id = "";
			jiraBundle.remote_integratable_id = "";
			
			jQuery('#jira_issue_icon a.jira_active').addClass('jira').removeClass('jira_active');
		}

		this.displayCreateWidget();
	},

	deleteJiraIssue:function(){
		this.showSpinner();
		self = this;
		reqData = {
				"integrated_resource[remote_integratable_id]":jiraBundle.remote_integratable_id,
				"integrated_resource[id]":jiraBundle.integrated_resource_id,
				"domain":jiraBundle.domain
			};
			new Ajax.Request("/integrations/jira_issue/delete", {
				asynchronous: true,
				method: "delete",
				parameters: reqData,
				onSuccess: function(evt){
					resJ = evt.responseJSON
					if (resJ['error'] == null || resJ['error'] == "") {
						jQuery('#jira_issue_icon a.jira_active').addClass('jira').removeClass('jira_active');
						jiraWidget.displayCreateWidget();
					} else {
						jiraException = self.jiraExceptionFilter(resJ['error']);

						if(jiraException == false)
							alert("Unknown server error. Please contact support@freshdesk.com.");
					}
					if (resultCallback) 
						resultCallback(evt);
				},
				onFailure: function(evt){
					if (resultCallback) 
						resultCallback(evt);
				}
			});
		
	},

	getCustomFieldData:function(resJson){
		var value="";
		if(jiraBundle.custom_field_id){
			jiraVer = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype.value.name");
			if(jiraVer != ""){
				value = ".value";
			}
			issueLinks = JsonUtil.getMultiNodeValue(resJson, "fields."+jiraBundle.custom_field_id+value);
			return issueLinks;
		}
	},

	displayCustomFieldData:function(resJson){
			issueLinks = this.getCustomFieldData(resJson);
			if(typeof issueLinks != "undefined"){
		  		issueHtml = this.formatIssueLinks(issueLinks);
		  		if(issueHtml != "duplicate_issue" || issueHtml != "")
		  		{
		  			jQuery('#jira-link-label').show();	
		  			jQuery('#jira-issue-link').html(issueHtml);		
		  		}
				
		  	} 

	},

	showSpinner: function() {
		jQuery('#jira_issue_loading').removeClass('hide');
		jQuery('.jira_issue_details, #jira_issue_forms').addClass('hide');
	}, 

	hideSpinner: function() {
		jQuery('#jira_issue_loading').addClass('hide');
		jQuery('.jira_issue_details, #jira_issue_forms').removeClass('hide');
	}, 

	processFailure: function(evt) {
		if (evt.status == 401) {
			alert("Username or password is incorrect.");
		} else if (evt.status == 404) {
			var error_json = evt.responseJSON
			alert(error_json['errorMessages']);
			jiraWidget.freshdeskWidget.delete_integrated_resource(jiraBundle.integrated_resource_id);
			jiraWidget.displayCreateWidget();
		} 
		else{
			// log("Server Error")
		}
	}
}

jiraWidget = new JiraWidget(jiraBundle);

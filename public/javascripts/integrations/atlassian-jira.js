var JiraWidget = Class.create();
JiraWidget.prototype= {
	JIRA_FORM:new Template(
		'<div id="jira_issue_create"><div class="heading"><span class="current_form">Create a new issue</span>' +
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
				'<input type="text" id="jira-issue-id" class="full"></input>' +
			'</div>' +
			'<input type="submit" id="jira-submit" class="uiButton" value="Link Issue" ' +
			'onclick="jiraWidget.linkJiraIssue();return false;"> '+
   	    '</form></div>'
		),
	JIRA_ISSUE:new Template(
		'<div id="jira-issue-widget">' +
		'<form id="jira-issue-form" method="post"> ' +
	    '<h3><span id="jira-issue-id"></span></h3>'+
	    '<h4><span id="jira-issue-summary"></span></h4>'+
	    '<span class="seperator"></span>'+
	    '<h4>Type</h4>'+
	    '<span id="jira-issue-type"></span>'+
	    '<br/><br/>'+
	    '<h4>Status</h4>'+
	    '<span id="jira-issue-status"></span>'+
	    '<br/><br/>'+
	    '<h4>Created On</h4>'+
	    '<span id="jira-issue-createdon"></span>'+
	    '<br/><br/>'+
	    '<h4 class="hide" id="jira-link-label">Linked Freshdesk Tickets</h4>'+
	    '<span id="jira-issue-link"></span>'+
	    '<br/>'+
	    '<input type="submit" id="jira-unlink" class="uiButton" style="margin-top: 1px;" value="Unlink Issue" ' +
   	    'onclick="jiraWidget.unlinkJiraIssue();return false;"> ' +
   	    '<input type="submit" id="jira-delete" class="uiButton" style="margin-top: 1px;" value="Delete Issue" ' +
   	    'onclick="jiraWidget.deleteJiraIssue();return false;"> ' +
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
				on_failure: jiraWidget.processFailure,
				on_success: jiraWidget.loadProject.bind(this)
			}];
		} 
		if(jiraBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				application_id:jiraBundle.application_id,
				app_name:"Jira",
				anchor:"jira_widget",
				domain:jiraBundle.domain,
				username:jiraBundle.username, 
				use_server_password: true,
				//password:jiraBundle.password,
				//ssl_enabled:harvestBundle.ssl_enabled || "false",
				login_content: null,
				application_content: function(){
					return jiraWidget.addToJira();
				},
				application_resources:init_reqs
			});
		}


		jQuery('.show_linkform, .show_createform').live('click',function(e) {
			e.preventDefault();
			jQuery('#jira_issue_create, #jira_issue_link').toggleClass('hide');
		});

	},	

	addToJira:function(){
		var appContent;
		if (jiraBundle.remote_integratable_id) {
			appContent = jiraWidget.JIRA_ISSUE.evaluate({});
		} else {
			appContent = jiraWidget.JIRA_FORM.evaluate({subject:jiraBundle.ticketSubject});
		}
		return appContent;
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
		console.log("Jira handleLoadProject.");
		console.log(this.projectData);
		selectedProjectNode = UIUtil.constructDropDown(this.projectData, "json", "jira-projects", null, "key", ["name"], null, Cookie.retrieve("jira_project_id")||"");
		//project_id = XmlUtil.getNodeValueStr(selectedProjectNode, "id");
		//this.projectChanged(project_id);

		UIUtil.hideLoading('jira','projects','');
	},

	loadIssueTypes:function(){
		console.log("Jira loadIssueTypes");
		reqData = {
				"domain":jiraBundle.domain
			};
			new Ajax.Request("/integrations/jira_issue/show", {
				asynchronous: true,
				method: "get",
				parameters: reqData,
				onSuccess: function(evt){
					resJ = evt.responseJSON
					if (resJ['status'] != 'error') {
						resData = evt;
						console.log(resData);
						this.handleLoadIssueTypes(resData);
					} else {
						console.log("Error fetching Issue types from Jira");
					}
					if (resultCallback) 
						resultCallback(evt);
				}.bind(this),
				onFailure: function(evt){
					console.log(evt);
					console.log(evt.responseText);
					console.log(jQuery(evt.responseText).find('pre').first().text());
					var error_message = jQuery(evt.responseText).find('pre').first().text();
					console.log("Error Message is " + error_message);
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
		console.log("Jira handleLoadIssueTypes");
		console.log(resData);
		//selectedProjectNode = UIUtil.constructDropDownJson(resData, "jira-issue-types", "types", "typeId", ["typeName"], null, Cookie.retrieve("jira_type_id")||"");
		selectedProjectNode = UIUtil.constructDropDown(resData, "json", "jira-issue-types", "types", "typeId", ["typeName"], null, Cookie.retrieve("jira_type_id")||"");

		UIUtil.hideLoading('jira','issue-types','');
	},

	createJiraIssue:function(resultCallback) {
		self = this;
		integratable_type = "issue-tracking";
		summary = jQuery('#jira-issue-summary').val();
		projectId = (jiraBundle.projectId) ? jiraBundle.projectId : jQuery('#jira-projects').val();
		typeId = (jiraBundle.typeId) ? jiraBundle.typeId : jQuery('#jira-issue-types').val();
		ticketSummary = (summary) ? summary : jiraBundle.ticketSubject;
		//ticketData = "Freshdesk Ticket #"+jiraBundle.ticketId+" -- " + document.URL;
		ticketData = "#"+jiraBundle.ticketId+" (" + document.URL +") - " + jiraBundle.ticketSubject;
		reqData = {
				"domain":jiraBundle.domain,
				"application_id": jiraBundle.application_id,
				"projectId": projectId,
				"issueTypeId":typeId,
				"summary":ticketSummary,
				"description":jiraBundle.jiraNote,
				"ticketData":ticketData,
				"integrated_resource[local_integratable_id]":jiraBundle.ticketId,
				"integrated_resource[local_integratable_type]": integratable_type

			};
			new Ajax.Request("/integrations/jira_issue/create", {
				asynchronous: true,
				method: "post",
				parameters: reqData,
				onSuccess: function(evt){
					resJ = evt.responseJSON
					jiraBundle.integrated_resource_id = resJ['integrated_resource']['id'];
					jiraBundle.remote_integratable_id = resJ['integrated_resource']['remote_integratable_id'];
					self.createdisplayIssueWidget();

					if (resultCallback) 
						resultCallback(evt);
				},
				onFailure: function(evt){
					if (resultCallback) 
						resultCallback(evt);
				}
			});
	},

	displayIssue:function(resData){
		console.log("Inside displayIssue");
		resJson = resData.responseJSON;
		var value="";
		var issueLink = jiraBundle.domain + "/browse/" + jiraBundle.remote_integratable_id;
		jiraVer = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype.value");
		if(jiraVer != ""){
			value = ".value";
		}
		fieldName = "fields.issuetype"+value+".name"
		var issueType = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype"+value+".name");
		var issueSummary = JsonUtil.getMultiNodeValue(resJson, "fields.summary"+value);
		var issueStatus = JsonUtil.getMultiNodeValue(resJson, "fields.status"+value+".name");
		var issueCreated = JsonUtil.getMultiNodeValue(resJson, "fields.created"+value);
		this.displayCustomFieldData(resJson);
		jQuery('#jira-issue-id').html("<h4><a target='_blank' href='" + issueLink + "'>" + jiraBundle.remote_integratable_id +"</a></h4>") ;
		jQuery('#jira-issue-type').text(issueType);
		jQuery('#jira-issue-summary').html("<h3>" + issueSummary + "</h3>");
		jQuery('#jira-issue-status').text(issueStatus);
		jQuery('#jira-issue-createdon').text(issueCreated);
		this.displayIssueWidgetStatus = false;
		 
	},

	formatIssueLinks:function(issueLinks){
		if(jiraWidget.linkIssue == true){
			currentURL = document.URL
			if(issueLinks.indexOf(currentURL) == -1){
				return "duplicate_issue"			
			}	
		}
		jiraIssues = issueLinks.split("\n");
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

	createdisplayIssueWidget:function(){
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
		
	},

	displayCreateWidget:function(){
		init_reqs = [{
				resource: "rest/api/latest/project",
				content_type: "application/json",
				on_failure: jiraWidget.processFailure,
				on_success: jiraWidget.loadProject.bind(this)
			}];
		jiraWidget.freshdeskWidget.options.application_content = this.displayFormContent;
		jiraWidget.freshdeskWidget.options.application_resources = init_reqs;
		jiraWidget.freshdeskWidget.display();
		console.log("Subject is " + jiraBundle.ticketSubject);
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
		return jiraWidget.JIRA_PARENT.evaluate({});
	},


	exportJiraIssue:function(){
		jiraWidget.linkIssueId = jQuery('#jira-issue-id').val();
		this.extractProjectId();
	},

	extractProjectId:function(){
		if(jiraWidget.linkIssueId){
			linkId = jiraWidget.linkIssueId;
			projectId = linkId.split("-");
			jiraBundle.projectId = projectId[0]; 
			jiraBundle.typeId = "1";
			jiraBundle.desc = "This issue duplicates " + linkId;
			this.createJiraIssue();
		}
	},
	
	linkJiraIssue:function(){
		remoteKey = jQuery('#jira-issue-id').val();
		jiraWidget.linkIssueId = remoteKey;
		this.freshdeskWidget.request({
				resource: "rest/api/latest/issue/"+remoteKey,
				content_type: "application/json",
				on_success: jiraWidget.updateIssue.bind(this),
				on_failure: jiraWidget.processFailure
			});
	},

	updateIssue:function(resData){
		self = this;
		var isCustomFieldDef = false
		integratable_type = "issue-tracking";
		freshdeskData = this.getCustomFieldData(resData.responseJSON);
		if (freshdeskData)
		{
			isCustomFieldDef = true;
			if (freshdeskData == "undefined" )
				freshdeskData = "#"+jiraBundle.ticketId+" (" + document.URL +") - " + jiraBundle.ticketSubject;
			else
				freshdeskData += "\n#"+jiraBundle.ticketId+" (" + document.URL +") - " + jiraBundle.ticketSubject;
			reqData = {
			"domain":jiraBundle.domain,	
			"isCustomFieldDef":"true",
			"customFieldId":jiraBundle.custom_field_id,
			"ticketData":freshdeskData,
			"remoteKey":jiraWidget.linkIssueId,
			"application_id": jiraBundle.application_id,
			"integrated_resource[local_integratable_id]":jiraBundle.ticketId,
			"integrated_resource[local_integratable_type]": integratable_type
			};
		}
		else
		{
			ticketData = "#"+" (" + document.URL +") - " + jiraBundle.ticketSubject;		
			reqData = {
				"domain":jiraBundle.domain,
				"remoteKey":jiraWidget.linkIssueId,
				"ticketData":ticketData,
				"isCustomFieldDef":"false",	
				"application_id": jiraBundle.application_id,
				"integrated_resource[local_integratable_id]":jiraBundle.ticketId,
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
					if (resJ['status'] != 'error') {
						jiraBundle.integrated_resource_id = resJ['integrated_resource']['id'];
						jiraBundle.remote_integratable_id = resJ['integrated_resource']['remote_integratable_id'];
						jiraWidget.linkIssue = true;
						self.createdisplayIssueWidget();
					}
					else{
						alert("Error linking the ticket with jira issue");
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
			this.freshdeskWidget.delete_integrated_resource(jiraBundle.integrated_resource_id);
			jiraBundle.integrated_resource_id = "";
			jiraBundle.remote_integratable_id = "";
			this.displayParentWidget();
		}
	},

	deleteJiraIssue:function(){
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
					if (resJ['status'] != 'error') {
						self.displayParentWidget();
					} else {
						console.log("Error while deleting the jira issue");
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
		if(jiraBundle.custom_field_id){
			issueLinks = JsonUtil.getMultiNodeValue(resJson, "fields."+jiraBundle.custom_field_id);
			return issueLinks;
		}
	},

	displayCustomFieldData:function(resJson){
		if(jiraBundle.custom_field_id){
		 	issueLinks = JsonUtil.getMultiNodeValue(resJson, "fields."+jiraBundle.custom_field_id);
		 	console.log(issueLinks)
		 	if(issueLinks != "undefined"){
		  		issueHtml = this.formatIssueLinks(issueLinks);
		  		if(issueHtml != "duplicate_issue")
		  		{
		  			jQuery('#jira-link-label').show();	
		  			jQuery('#jira-issue-link').html(issueHtml);		
		  		}
				
		  	}
		 }
	}
}

jiraWidget = new JiraWidget(jiraBundle);

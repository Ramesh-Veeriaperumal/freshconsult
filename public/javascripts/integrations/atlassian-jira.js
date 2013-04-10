var JiraWidget = Class.create();
JiraWidget.prototype = {
	JIRA_FORM:new Template(
		'<div id="jira_issue_forms"><div id="jira_issue_create"><div class="heading"><span class="current_form">Create a new issue</span>' +
			'<span class="divider"> or </span>' + 
			' <span class="other_form show_linkform">Link to an existing issue</span></div>' + 
	    '<form id="jira-add-form" method="post" class="ui-form"> ' +
		    '<div class="field half_width left">' +
			    '<label>Project</label> ' +
			    '<select class="full hide" name="fields[project][id]" id="jira-projects" onchange="jiraWidget.projectChanged(this.options[this.selectedIndex].value)"></select> ' +
			    '<div class="loading-fb" id="jira-projects-spinner"> </div>' + 
		    '</div>' + 
		    '<div class="field half_width right">' +
			    '<label>Issue Type</label> ' +
			    '<select class="full hide" name="fields[issuetype][id]" id="jira-issue-types" onchange="jiraWidget.typeChanged(this.options[this.selectedIndex].value)"></select> ' +
			    '<div class="loading-fb" id="jira-issue-types-spinner"> </div>' + 
		    '</div>' + 
		    '<div class="field" id="fields">' +
		    '<div class="loading-fb" id="jira-field-spinner"> </div>'+
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

	initialize: function(jiraBundle) {
		jiraWidget = this; // Assigning to some variable so that it can be accessible inside custom_widget.
		this.projectData = "";
		var init_reqs = [];
		if(jiraBundle.remote_integratable_id) {
			init_reqs = [{
				rest_url: "rest/api/latest/issue/" + jiraBundle.remote_integratable_id,
				content_type: "application/json",
				on_failure: jiraWidget.processFailureCreate,
				on_success: jiraWidget.displayIssue.bind(this)
			}];
		} else {
			init_reqs = [{
				source_url: "/integrations/jira_issue/fetch_jira_projects_issues",
				content_type: "application/json",
				on_success: jiraWidget.loadProject.bind(this),
				on_failure: jiraWidget.processFailure.bind(this)
			}];
			jQuery('#jira_issue_loading').addClass('hide');

		}
		if(jiraBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				app_name: "Jira",
				domain: jiraBundle.domain,
				application_id: jiraBundle.application_id,
				username: jiraBundle.username,
				use_server_password: true,
				login_html: null,
				application_html: function() {
					if(jiraBundle.remote_integratable_id) {
						return jiraWidget.JIRA_ISSUE.evaluate({});
					} else {
						return jiraWidget.JIRA_FORM.evaluate({
							subject: jiraBundle.ticketSubject.replace(/"/g, "&quot;")
						});
					}
				},
				init_requests: init_reqs
			});
		}

		jQuery('.show_linkform, .show_createform').live('click', function(e) {
			e.preventDefault();
			jQuery('#jira_issue_create, #jira_issue_link').toggleClass('hide');
		});

		jQuery('#jira-unlink').live('click', function(ev) {
			ev.preventDefault();
			jiraWidget.unlinkJiraIssue();
		});

		jQuery('#jira-delete').live('click', function(ev) {
			ev.preventDefault();
			jiraWidget.deleteJiraIssue();
		});

	},

	loadProject: function(resData) {
		this.projectData = resData;
		this.handleLoadProject(resData);
		this.loadIssueTypes(resData);
	},

	projectChanged: function(project_id) {
		Cookie.update("jira_project_id", project_id);
		jiraWidget.getCustomFieldDetails();
	},

	handleLoadProject: function(resData) {
		selectedProjectNode = UIUtil.constructDropDown(this.projectData.responseJSON["res_projects"], "json", "jira-projects", null, "id", ["name"], null, Cookie.retrieve("jira_project_id") || "");
		UIUtil.hideLoading('jira', 'projects', '');
	},

	loadIssueTypes: function(resData) {
		this.projectData = resData;
		this.handleLoadIssueTypes(resData);
		this.getCustomFieldDetails();
	},

	typeChanged: function(type_id) {
		//alert("Issue Type ID : " + type_id);
		Cookie.update("jira_type_id", type_id);
		jiraWidget.getCustomFieldDetails();
	},

	getCustomFieldDetails:function()
	{
		jQuery('#jira-submit').attr("disabled",true);
		jQuery("#fields").html("<div class='loading-fb' id='jira-field-spinner'> </div>");
		project_id = jQuery('#jira-projects').val();
		type_id = jQuery('#jira-issue-types').val();
		init_reqs = [{
			rest_url : "rest/api/latest/issue/createmeta?expand=projects.issuetypes.fields&projectIds="+project_id+"&issuetypeIds="+type_id,
			method: "get",
			content_type: "application/json",
			on_success:jiraWidget.constructFieldsDynamically.bind(this),
			on_failure:jiraWidget.processFailureCustomFields.bind(this)
		}];
		jiraWidget.freshdeskWidget.options.init_requests = init_reqs;
		jiraWidget.freshdeskWidget.call_init_requests();
	},

	constructFieldsDynamically: function(evt){
		resJson = evt.responseJSON;
		jiraWidget.selectOnlyRequiredFields(resJson);
	},
	processFailureCustomFields: function(evt){

	},
	selectOnlyRequiredFields:function(resJson){
		jiraWidget.customFieldData = {}
		jQuery.each(resJson.projects[0].issuetypes[0].fields,function(field_key,field_value){
			if(field_value["required"]&& (field_key != "issuetype" && field_key != "project")){
				jiraWidget.customFieldData[field_key] = field_value; 
			}
		});
		jiraWidget.processJiraFields();
	},

	handleLoadIssueTypes: function(resData) {
		issueData = this.projectData.responseJSON["res_issues"];
		actualData =[]
		jQuery.each(issueData,function(key,value){
			if(!value["subtask"])
				actualData.push(value);

		});
		selectedProjectNode = UIUtil.constructDropDown(actualData, "json", "jira-issue-types", null, "id", ["name"], null, Cookie.retrieve("jira_type_id") || "");
		UIUtil.hideLoading('jira', 'issue-types', '');
	},

	getCurrentUrl: function() {
		current_url = document.URL;
		domain_url = current_url.split("helpdesk/tickets");
		ticket_url = domain_url[0] + "helpdesk/tickets" + "/" + jiraBundle.ticketId;
		return ticket_url;
	},

	createJiraIssue: function(resultCallback) {
		if(jiraWidget.form_validation())
		{
			return false;
		}
		this.showSpinner();
		self = this;
		integratable_type = "issue-tracking";
		projectId = (jiraBundle.projectId) ? jiraBundle.projectId : jQuery('#jira-projects').val();
		typeId = (jiraBundle.typeId) ? jiraBundle.typeId : jQuery('#jira-issue-types').val();
		ticketData = "#" + jiraBundle.ticketId + " (" + jiraWidget.getCurrentUrl() + ") - " + jiraBundle.ticketSubject;
		jiraWidget.jiraCreateSummaryAndDescription();
		init_reqs = [{
			source_url: "/integrations/jira_issue/create",
			content_type: "application/json",
			local_integratable_id: jiraBundle.ticket_rawId,
			local_integratable_type: integratable_type,
			application_id: jiraBundle.application_id,
			ticket_data: ticketData,
			method: "post",
			on_success: jiraWidget.jiraCreateIssueSuccess.bind(this),
			on_failure: jiraWidget.jiraCreateIssueFailure.bind(this),
			body: Object.toJSON(jQuery("#jira-add-form").serializeObject())
		}];
		jiraWidget.freshdeskWidget.options.init_requests = init_reqs
		jiraWidget.freshdeskWidget.call_init_requests();
	},
	jiraCreateSummaryAndDescription: function(){
		if(jQuery('input[name="fields[description]"]').size() == 0)
		{
			jQuery('<input>').attr({
			type:'hidden',
			id: 'fields[description]',
			name: 'fields[description]',
			value: jQuery("#jira-note").text()}).appendTo('#jira-add-form');
		}
		if(jQuery('input[name="fields[summary]"]').size() == 0)
		{
			jQuery('<input>').attr({
			type:'hidden',
			id: 'fields[summary]',
			name: 'fields[summary]',
			value: jiraBundle.ticketSubject}).appendTo('#jira-add-form');
		}
	},
	jiraCreateIssueSuccess: function(evt) {
		resJ = evt.responseJSON
		if(resJ['error'] == null || resJ['error'] == "") {
			jiraBundle.integrated_resource_id = resJ['integrated_resource']['id'];
			jiraBundle.remote_integratable_id = resJ['integrated_resource']['remote_integratable_id'];
			jiraBundle.custom_field_id = resJ['integrated_resource']['custom_field'];
			jiraWidget.renderDisplayIssueWidget();
		} else {
			jiraException = self.jiraExceptionFilter(resJ['error'])
			if(jiraException == false) alert("Unknown server error. Please contact support@freshdesk.com.");
			jiraWidget.displayCreateWidget();
			return
		}

		jQuery('#jira_issue_icon a.jira').removeClass('jira').addClass('jira_active');
		if(resultCallback) resultCallback(evt);

	},	
	jiraCreateIssueFailure: function(evt) {
		if(resultCallback) resultCallback(evt);
	},

	jiraExceptionFilter: function(errMsg) {
		if(errMsg.indexOf("Exception:") != -1) {
			jiraMsg = errMsg.split("Exception:")
			alert("Jira reports the below error:\n\n" + jiraMsg[1] + "\n\n Please contact Support.");
			return true;
		} else return false;
	},

	displayIssue: function(resData) {
		resJson = resData.responseJSON;
		var value = "";
		var issueLink = jiraBundle.domain + "/browse/" + resJson["key"];
		jiraBundle.remote_integratable_id = resJson["key"];
		jiraVer = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype.value.name");
		if(jiraVer != "") {
			value = ".value";
		}
		fieldName = "fields.issuetype" + value + ".name"
		var issueType = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype" + value + ".name");

		var issueSummary = JsonUtil.getMultiNodeValue(resJson, "fields.summary" + value);
		var issueStatus = JsonUtil.getMultiNodeValue(resJson, "fields.status" + value + ".name");
		var issueCreated = JsonUtil.getMultiNodeValue(resJson, "fields.created" + value);
		if(jiraBundle.custom_field_id) {
			this.displayCustomFieldData(resJson, value);
		}
		if(issueStatus == "Resolved" || issueStatus == "Closed") issueIdHtml = "<a class='strikethrough' target='_blank' href='" + issueLink + "'>" + resJson["key"] + "</a>";
		else issueIdHtml = "<a target='_blank' href='" + issueLink + "'>" + resJson["key"] + "</a>";
		jQuery('#jira-issue-id').html(issueIdHtml);
		jQuery('#jira-view').attr("href", issueLink);
		jQuery('#jira-issue-type').text(issueType);
		jQuery('#jira-issue-summary').html(issueSummary);
		jQuery('#jira-issue-status').text(issueStatus);
		jQuery('#jira-issue-createdon').text(freshdate(issueCreated));
		this.displayIssueWidgetStatus = false;
		this.hideSpinner();


		jQuery('#jira_issue_loading').addClass('hide');
		jQuery('.jira_issue_details').removeClass('hide');

	},

	formatIssueLinks: function(issueLinks) {
		jiraIssues = issueLinks.split("\n");
		jiraWidget.ticketData = issueLinks;
		jiraWidget.unlinkId = jiraBundle.remote_integratable_id;
		var issueHtml = "";
		for(var i = 0; i < jiraIssues.length; i++) {
			startUrl = jiraIssues[i].indexOf('(');
			endUrl = jiraIssues[i].indexOf(')');
			if(startUrl != null && endUrl != null) {
				ticketUrl = jiraIssues[i].slice(startUrl + 1, endUrl);
			}
			if(ticketUrl) {
				ticket = jiraIssues[i].split(" - ");
				ticketMain = ticket[0].split(" (");
				issueHtml += "<a target='_blank' href='" + ticketUrl + "'>" + ticketMain[0] + " - " + ticket[1] + "</a><br/>";
			}

		}
		return issueHtml;
	},

	renderDisplayIssueWidget: function() {
		init_reqs = [{
			rest_url: "rest/api/latest/issue/" + jiraBundle.remote_integratable_id,
			content_type: "application/json",
			on_failure: jiraWidget.processFailure,
			on_success: jiraWidget.displayIssue.bind(this)
		}];
		jiraWidget.freshdeskWidget.options.application_html = this.displayIssueContent
		jiraWidget.freshdeskWidget.options.init_requests = init_reqs;
		jiraWidget.freshdeskWidget.display();
		jiraWidget.freshdeskWidget.call_init_requests();

		//Show loading
		this.showSpinner();

	},

	displayCreateWidget: function() {
		this.hideSpinner();
		init_reqs = [{
			source_url: "/integrations/jira_issue/fetch_jira_projects_issues",
			content_type: "application/json",
			on_failure: jiraWidget.processFailure,
			on_success: jiraWidget.loadProject.bind(this)
		}];
		jiraWidget.freshdeskWidget.options.application_html = this.displayFormContent;
		jiraWidget.freshdeskWidget.options.init_requests = init_reqs;
		jiraWidget.freshdeskWidget.display();
		jiraWidget.freshdeskWidget.call_init_requests();
		jQuery('#jira-issue-summary').val(jiraBundle.ticketSubject);


	},

	displayLinkWidget: function() {
		jiraWidget.freshdeskWidget.options.application_html = this.displayLinkContent;
		jiraWidget.freshdeskWidget.options.init_requests = null;
		jiraWidget.freshdeskWidget.display();

	},

	displayParentWidget: function() {
		jiraWidget.freshdeskWidget.options.application_html = this.displayParentContent;
		jiraWidget.freshdeskWidget.options.init_requests = null;
		jiraWidget.freshdeskWidget.display();
	},

	displayIssueContent: function() {
		return jiraWidget.JIRA_ISSUE.evaluate({});
	},

	displayFormContent: function() {
		return jiraWidget.JIRA_FORM.evaluate({});
	},

	displayLinkContent: function() {
		return jiraWidget.JIRA_LINK.evaluate({});
	},

	displayParentContent: function() {
		return jiraWidget.JIRA_FORM.evaluate({});
	},


	linkJiraIssue: function() {
		this.showSpinner();

		remoteKey = jQuery('#jira-issue-id').val();
		jiraWidget.linkIssueId = remoteKey;
		jiraWidget.linkedTicket = ""
		this.freshdeskWidget.request({
			rest_url: "rest/api/latest/issue/" + encodeURIComponent(remoteKey),
			content_type: "application/json",
			on_success: jiraWidget.updateIssue.bind(this),
			on_failure: jiraWidget.processFailureLinking
		});
	},
	processFailureLinking: function(evt) {
		if(evt.status == 401) alert("Username or password is incorrect.");
		else {
			alert("Jira reports the following error : " + evt.responseJSON.errorMessages[0]);
		}
		jiraWidget.displayCreateWidget();
	},
	updateIssue: function(resData) {
		self = this;
		var isCustomFieldDef = false;
		var freshdeskData;
		integratable_type = "issue-tracking";
		if(resData) freshdeskData = this.getCustomFieldData(resData.responseJSON);
		reqData = {
			"update": {}
		};
		if(freshdeskData != null) {
			if(freshdeskData.indexOf(jiraWidget.getCurrentUrl()) != -1) ticketData = freshdeskData;
			else {
				isCustomFieldDef = true;
				if(freshdeskData == "undefined" || freshdeskData == "") ticketData = "#" + jiraBundle.ticketId + " (" + jiraWidget.getCurrentUrl() + ") - " + jiraBundle.ticketSubject;
				else ticketData = freshdeskData + "\n#" + jiraBundle.ticketId + " (" + jiraWidget.getCurrentUrl() + ") - " + jiraBundle.ticketSubject;
			}
			init_reqs = [{
				content_type: "application/json",
				on_success: jiraWidget.updateIssueJiraSuccess.bind(this),
				on_failure: jiraWidget.updateIssueJiraFailure.bind(this),
				ticket_data: ticketData,
				method: "put",
				remote_key: jiraWidget.linkIssueId,
				domain: jiraBundle.domain,
				isCustomFieldDef: "true",
				application_id: jiraBundle.application_id,
				local_integratable_id: jiraBundle.ticket_rawId,
				local_integratable_type: integratable_type,
				source_url: "/integrations/jira_issue/update"

			}];
		} else {
			ticketData = "#" + jiraBundle.ticketId + " (" + jiraWidget.getCurrentUrl() + ") - " + jiraBundle.ticketSubject;
			init_reqs = [{
				method: "post",
				remote_key: jiraWidget.linkIssueId,
				domain: jiraBundle.domain,
				ticket_data: ticketData,
				isCustomFieldDef: "false",
				application_id: jiraBundle.application_id,
				local_integratable_id: jiraBundle.ticket_rawId,
				local_integratable_type: integratable_type,
				source_url: "/integrations/jira_issue/update",
				on_success: jiraWidget.updateIssueJiraSuccess.bind(this),
				on_failure: jiraWidget.updateIssueJiraFailure.bind(this)
			}];
		}
		jiraWidget.freshdeskWidget.options.init_requests = init_reqs;
		jiraWidget.freshdeskWidget.call_init_requests();

	},
	updateIssueJiraSuccess: function(evt) {
		resJ = evt.responseJSON
		displayIssue = true;
		if(resJ['error'] == null || resJ['error'] == "") {
			jiraBundle.integrated_resource_id = resJ['integrated_resource']['id'];
			jiraBundle.remote_integratable_id = resJ['integrated_resource']['remote_integratable_id'];
			jiraWidget.linkIssue = true;
			jiraBundle.custom_field_id = resJ['integrated_resource']['custom_field'];

			jQuery('#jira_issue_icon a.jira').removeClass('jira').addClass('jira_active');
			jiraWidget.renderDisplayIssueWidget();
		} else {
			jiraException = self.jiraExceptionFilter(resJ['error'])
			if(jiraException == false) alert("Unknown server error. Please contact support@freshdesk.com.");
		}

		if(resultCallback) resultCallback(evt);
	},
	updateIssueJiraFailure: function(evt) {
		if(resultCallback) resultCallback(evt);
	},
	unlinkJiraIssue: function() {
		if(jiraBundle.integrated_resource_id) {
			this.showSpinner();
			ticketData = "";
			if(jiraWidget.ticketData) {
				linkedTicket = "#" + jiraBundle.ticketId + " (" + jiraWidget.getCurrentUrl() + ") - " + jiraBundle.ticketSubject;
				fdTickets = jiraWidget.ticketData.split("\n");
				for(var i = 0; i < fdTickets.length; i++) {
					if(fdTickets[i].trim() != '' && fdTickets[i] != linkedTicket) {
						ticketData += fdTickets[i] + "\n";
					}
				}
			}
			init_reqs = [{
				rest_url: "rest/api/latest/issue/" + jiraWidget.unlinkId,
				source_url: "/integrations/jira_issue/unlink",
				method: "put",
				remote_key: jiraWidget.unlinkId,
				ticket_data: ticketData,
				domain: jiraBundle.domain,
				id: jiraBundle.integrated_resource_id,
				on_success: jiraWidget.unlinkJiraIssueSuccess.bind(this),
				on_failure: jiraWidget.unlinkJiraIssueFailure.bind(this)
			}];
			jiraWidget.freshdeskWidget.options.init_requests = init_reqs;
			jiraWidget.freshdeskWidget.call_init_requests();
			jiraBundle.integrated_resource_id = "";
			jiraBundle.remote_integratable_id = "";

			jQuery('#jira_issue_icon a.jira_active').addClass('jira').removeClass('jira_active');
		}

		this.displayCreateWidget();
	},
	unlinkJiraIssueSuccess: function(evt) {
		resJ = evt.responseJSON
		if(resJ['error'] == null || resJ['error'] == "") {

		} else {
			jiraException = self.jiraExceptionFilter(resJ['error'])
			if(jiraException == false) alert("Unknown server error. Please contact support@freshdesk.com.");
		}
		if(resultCallback) resultCallback(evt);
	},
	unlinkJiraIssueFailure: function(evt) {
		if(resultCallback) resultCallback(evt);
	},
	deleteJiraIssue: function() {
		this.showSpinner();
		self = this;
		init_reqs = [{
			rest_url: "rest/api/latest/issue/" + jiraBundle.remote_integratable_id,
			content_type: "application/json",
			method: "delete",
			deleteSubtasks: true,
			remote_integratable_id: jiraBundle.remote_integratable_id,
			id: jiraBundle.integrated_resource_id,
			domain: jiraBundle.domain,
			on_success: jiraWidget.deleteJiraIssueSuccess.bind(this),
			on_failure: jiraWidget.deleteJiraIssueFailure.bind(this),
			source_url: "/integrations/jira_issue/destroy"
		}];
		jiraWidget.freshdeskWidget.options.init_requests = init_reqs;
		jiraWidget.freshdeskWidget.call_init_requests();
	},
	deleteJiraIssueSuccess: function(evt) {
		resJ = evt.responseJSON
		if(resJ['error'] == null || resJ['error'] == "") {
			jQuery('#jira_issue_icon a.jira_active').addClass('jira').removeClass('jira_active');
			jiraWidget.displayCreateWidget();
		} else {
			jiraException = self.jiraExceptionFilter(resJ['error']);
			if(jiraException == false) alert("Unknown server error. Please contact support@freshdesk.com.");
			jiraWidget.renderDisplayIssueWidget();
		}
		if(resultCallback) resultCallback(evt);
	},
	deleteJiraIssueFailure: function(evt) {
		if(resultCallback) resultCallback(evt);
	},
	getCustomFieldData: function(resJson) {
		var value = "";
		if(jiraBundle.custom_field_id) {
			jiraVer = JsonUtil.getMultiNodeValue(resJson, "fields.issuetype.value.name");
			if(jiraVer != "") {
				value = ".value";
			}
			issueLinks = JsonUtil.getMultiNodeValue(resJson, "fields." + jiraBundle.custom_field_id + value);
			return issueLinks;
		}
	},

	displayCustomFieldData: function(resJson) {
		issueLinks = this.getCustomFieldData(resJson);
		if(typeof issueLinks != "undefined") {
			issueHtml = this.formatIssueLinks(issueLinks);
			if(issueHtml != "duplicate_issue" || issueHtml != "") {
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
		if(evt.status == 401) alert("Username or password is incorrect.");
		else {
			alert("Jira reports the following error : " + evt.responseJSON.errorMessages[0]);
		}
	},

	processFailureCreate: function(evt) {
		if(evt.status == 404) {
			jiraWidget.freshdeskWidget.delete_integrated_resource(jiraBundle.integrated_resource_id);
			jiraWidget.displayCreateWidget();
		} else {
			this.processFailure(evt);
		}
	},

	processJiraFields:function(fieldKey,fieldData){
		jiraWidget.fieldContainer = "";
		jQuery.each(jiraWidget.customFieldData, function(fieldKey, fieldData){
		functionName = "processJiraField"+(fieldData["schema"]["type"]).capitalize();
		var args=[];
		args.push(fieldKey,fieldData);
		callerObject = window["jiraWidget"][functionName]
		if(callerObject)  
			callerObject.apply(null, args);
		else 
			jiraWidget.processJiraFieldString(fieldKey, fieldData);
		});
		jQuery("#fields").html(jiraWidget.fieldContainer);
		jQuery('#jira-submit').removeAttr('disabled');
	},

	processJiraFieldPriority:function(fieldKey,fieldData)
	{
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>';
		jiraWidget.fieldContainer += '<select name="fields['+ fieldKey+'][id]">';
		selectOptions = "";
		jQuery.each(fieldData["allowedValues"],function(key,data){
			selectOptions += "<option value='"+data["id"]+"'>"+data["name"]+"</option>";
		});
		jiraWidget.fieldContainer += selectOptions+ '</select>';
	},
	processJiraFieldUser:function(fieldKey,fieldData)
	{
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>'+
				'<input type="text" name="fields['+fieldKey+'][name]" id="fields['+ fieldKey+'][name]" value="'+jiraBundle.username+'"/>';
	
	},
	processJiraFieldTimetracking:function(fieldKey,fieldData){
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>';
		jiraWidget.fieldContainer += '<label>Orginal Estimate</label>'+
				'<input type="text" name="fields['+fieldKey+'][originalEstimate]" id="fields['+ fieldKey+'][originalEstimate]" value="" placeholder="1d 10h 20m"/>';
		jiraWidget.fieldContainer += '<label>Remaining Estimate</label>'+
				'<input type="text" name="fields['+fieldKey+'][remainingEstimate]" id="fields['+ fieldKey+'][remainingEstimate]" value="" placeholder="1d 5h 5m"/>';
		
	},
	processJiraFieldDate:function(fieldKey,fieldData){
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>';
		jiraWidget.fieldContainer += '<input type="text" class="datepicker_popover" name="fields['+fieldKey+']" id="'+ fieldKey+'"/>';
	},
	processJiraFieldDatetime:function(fieldKey,fieldData){
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>';
		jiraWidget.fieldContainer += '<input type="text" class="datetimepicker_popover" name="fields['+fieldKey+']" id="'+ fieldKey+'"/>';
	},
	processJiraFieldString:function(fieldKey,fieldData){
		if(fieldData["allowedValues"]){
			jiraWidget.ProcessJiraFieldArrayStringAllowedValues(fieldKey,fieldData);
		}	
		else{	
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>';
		if(fieldData["name"] == "Summary")
			jiraWidget.fieldContainer += '<input type="text" name="fields['+fieldKey+']" id="fields['+ fieldKey+']	" value="'+jQuery(".request-title .subject").text()+'"/>';
		else
			jiraWidget.fieldContainer += '<input type="text" name="fields['+fieldKey+']" id="fields['+ fieldKey+']	"/>';
		}
	},
	processJiraFieldNumber:function(fieldKey,fieldData){
		if(fieldData["allowedValues"]){
			jiraWidget.ProcessJiraFieldArrayStringAllowedValues(fieldKey,fieldData);
		}
		jiraWidget.fieldContainer += '<label>'+fieldData["name"]+'</label>';
		jiraWidget.fieldContainer += '<input type="text" name="fields['+fieldKey+']" id="fields['+ fieldKey+']	"/>';		
	},
	processJiraFieldArray:function(fieldKey,fieldData){
		if(fieldData["schema"]["items"] == "string"){
			if(fieldData["allowedValues"])
				jiraWidget.ProcessJiraFieldArrayStringAllowedValues(fieldKey,fieldData);
			else
				jiraWidget.processJiraFieldArrayString(fieldKey,fieldData);
		}
		else{
			if(fieldData["allowedValues"])
				jiraWidget.processJiraFieldArrayObjectAllowedValues(fieldKey,fieldData);
			else
				jiraWidget.processJiraFieldArrayObject(fieldKey,fieldData);

		}
	},
	processJiraFieldArrayString:function(fieldKey,fieldData){
		jiraWidget.fieldContainer += '<label>' + fieldData["name"] + '</label>';
		jiraWidget.fieldContainer += '<input type="text" class ="array" name="fields[' + fieldKey + ']" id="fields[' + fieldKey + '] " value="" placeholder="label1,label2"/>';
	}, 
	processJiraFieldArrayObject: function(fieldKey, fieldData) {
		jiraWidget.fieldContainer += '<label>' + fieldData["name"] + '</label>';
		jiraWidget.fieldContainer += '<input type="text"  name="fields[' + fieldKey + '][0][id]" id="fields[' + fieldKey + ']	"/>';
	},
	processJiraFieldArrayObjectAllowedValues: function(fieldKey, fieldData) {
		jiraWidget.fieldContainer += '<label>' + fieldData["name"] + '</label>';
		jiraWidget.fieldContainer += '<select name="fields['+ fieldKey+'][0][id]">';
		selectOptions = "";
		jQuery.each(fieldData["allowedValues"],function(key,data){
			selectOptions += "<option value='"+data["id"]+"'>"+data["name"]+"</option>";
		});
		jiraWidget.fieldContainer += selectOptions+ '</select>';
	}, 
	ProcessJiraFieldArrayStringAllowedValues: function(fieldKey, fieldData) {
		jiraWidget.fieldContainer += '<label>' + fieldData["name"] + '</label>';
		if(fieldData["schema"]["type"] == "string")
			jiraWidget.fieldContainer += '<select name="fields['+ fieldKey+']">';
		else
		jiraWidget.fieldContainer += '<select name="fields['+ fieldKey+'][0]">';
		selectOptions = "";
		jQuery.each(fieldData["allowedValues"],function(key,data){
			selectOptions += "<option value='"+data["id"]+"'>"+data["name"]+"</option>";
		});
		jiraWidget.fieldContainer += selectOptions+ '</select>';
	},
	
	form_validation:function(){
		var error = [];
		var flag = false;
		jQuery.each(jQuery("#jira-add-form").find("input"),function(){
			if (this.value == "undefined" || this.value == "" || this.value.trim()=="")
			{
				error.push(jQuery(this).prev().text());
			}
		});
		if(error.length > 0){
			alert("please fill the columns:" + error.join(","));
			flag=true;
		}
		return flag;
	},
	
}

jiraWidget = new JiraWidget(jiraBundle);
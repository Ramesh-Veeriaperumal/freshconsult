var FreshbooksWidget = Class.create();
FreshbooksWidget.prototype = {
	FRESHBOOKS_FORM:new Template('<form id="freshbooks-timeentry-form"><div class="field first"><label>Staff</label><select name="staff-id" id="freshbooks-timeentry-staff" onchange="Freshdesk.NativeIntegration.freshbooksWidget.staffChanged(this.options[this.selectedIndex].value)" disabled class="full hide"></select> <div class="loading-fb" id="freshbooks-staff-spinner"></div></div><div class="field"><label>Client</label><select name="client-id" id="freshbooks-timeentry-clients" class="full hide" disabled onchange="Freshdesk.NativeIntegration.freshbooksWidget.clientChanged(this.options[this.selectedIndex].value)"></select> <div class="loading-fb" id="freshbooks-clients-spinner"></div></div><div class="field"><label>Project</label><select class="full hide" name="project-id" id="freshbooks-timeentry-projects" onchange="Freshdesk.NativeIntegration.freshbooksWidget.projectChanged(this.options[this.selectedIndex].value)" disabled></select> <div class="loading-fb" id="freshbooks-projects-spinner"></div></div><div class="field last"><label>Task</label><select class="full hide" disabled name="task-id" id="freshbooks-timeentry-tasks" onchange="Freshdesk.NativeIntegration.freshbooksWidget.taskChanged(this.options[this.selectedIndex].value)"></select> <div class="loading-fb" id="freshbooks-tasks-spinner" ></div></div><div class="field"><label id="freshbooks-timeentry-notes-label">Notes</label><textarea disabled name="notes" id="freshbooks-timeentry-notes" wrap="virtual">'+ jQuery('#freshbooks-note').html() +'</textarea></div><div class="field"><label id="freshbooks-timeentry-hours-label">Hours</label><input type="text" disabled name="hours" id="freshbooks-timeentry-hours"></div><input type="submit" disabled id="freshbooks-timeentry-submit" value="Submit" onclick="Freshdesk.NativeIntegration.freshbooksWidget.logTimeEntry($(\'freshbooks-timeentry-form\'));return false;"></form>'),
	STAFF_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="staff.list"></request>'),
	CLIENT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="client.list"> <page>#{page}</page><per_page>100</per_page><folder>active</folder></request>'),
	PROJECT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="project.list"> <page>#{page}</page><per_page>100</per_page></request>'),
	TASK_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?> <request method="task.list" > <project_id>#{project_id}</project_id> </request>'),
	CREATE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.create"> <time_entry> <project_id>#{project_id}</project_id> <task_id>#{task_id}</task_id> <hours>#{hours}</hours> <date>#{date}</date> <notes><![CDATA[#{notes}]]></notes> <staff_id>#{staff_id}</staff_id> </time_entry></request>'),
	RETRIEVE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.get"> <time_entry_id>#{time_entry_id}</time_entry_id> </request>'),
	UPDATE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.update"> <time_entry> <time_entry_id>#{time_entry_id}</time_entry_id> <project_id>#{project_id}</project_id> <task_id>#{task_id}</task_id> <staff_id>#{staff_id}</staff_id> <hours>#{hours}</hours> <date>#{date}</date> <notes><![CDATA[#{notes}]]></notes> </time_entry></request>'),
	UPDATE_TIMEENTRY_ONLY_HOURS_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.update"> <time_entry> <time_entry_id>#{time_entry_id}</time_entry_id> <hours>#{hours}</hours> </time_entry></request>'),
	DELETE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.delete"> <time_entry_id>#{time_entry_id}</time_entry_id> </request>'),

	initialize:function(freshbooksBundle, loadInline){
		Freshdesk.NativeIntegration.freshbooksWidget = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.projectData = ""; init_reqs = []; this.executed_date = new Date(); this.projectResults = "";
		freshbooksBundle.freshbooksNote = jQuery('#freshbooks-note').html();
		init_reqs = [null, {
			body: Freshdesk.NativeIntegration.freshbooksWidget.STAFF_LIST_REQ.evaluate({}),
			content_type: "application/xml",
			method: "post", 
			on_success: Freshdesk.NativeIntegration.freshbooksWidget.loadStaffList.bind(this),
			on_failure: function(evt){}
		}, {
			body: Freshdesk.NativeIntegration.freshbooksWidget.CLIENT_LIST_REQ.evaluate({page:1}),
			content_type: "application/xml",
			method: "post", 
			on_success: Freshdesk.NativeIntegration.freshbooksWidget.loadClientList.bind(this)
		}, {
			body: Freshdesk.NativeIntegration.freshbooksWidget.PROJECT_LIST_REQ.evaluate({page:1}),
			content_type: "application/xml",
			method: "post", 
			on_success: Freshdesk.NativeIntegration.freshbooksWidget.loadProjectList.bind(this),
			on_failure: function(evt){}
		}]
		if (freshbooksBundle.remote_integratable_id)
			init_reqs[0] = {
				body: Freshdesk.NativeIntegration.freshbooksWidget.RETRIEVE_TIMEENTRY_REQ.evaluate({
					time_entry_id: freshbooksBundle.remote_integratable_id
				}),
				content_type: "application/xml",
				method: "post", 
				on_success: Freshdesk.NativeIntegration.freshbooksWidget.loadTimeEntry.bind(this),
				on_failure: function(evt){}
			}
		freshbooksOptions = {
			app_name:"Freshbooks",
			application_id:freshbooksBundle.application_id,
			integratable_type:"timesheet",
		    use_server_password:true,
		    auth_type:"NoAuth",
		    ssl_enabled:true,
			domain: freshbooksBundle.domain,
			application_html: function() {
				return Freshdesk.NativeIntegration.freshbooksWidget.FRESHBOOKS_FORM.evaluate({});
			},
			init_requests: init_reqs
		};

		if (typeof(freshbooksBundle) == 'undefined') {
			freshbooksOptions.login_html = function() {
				return '<form onsubmit="Freshdesk.NativeIntegration.freshbooksWidget.login(this); return false;" class="form">' + '<label>Authentication Key</label><input type="password" id="username"/>' + '<input type="hidden" id="password" value="X"/>' + '<input type="submit" value="Login" id="submit">' + '</form>';
			};
		}

		this.freshdeskWidget = new Freshdesk.Widget(freshbooksOptions);
		if(loadInline) this.convertToInlineWidget();
	},

	loadTimeEntry: function(resData) {
		if (resData && this.isRespSuccessful(resData.responseXML)) {
			this.timeEntryXml = resData.responseXML;
			this.resetTimeEntryForm();
		}
	},

	loadStaffList:function(resData){
		if (this.timeEntryXml)
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "staff_id")
		else
			searchTerm = freshbooksBundle.agentEmail
		
		
		this.loadFreshbooksEntries(resData, "freshbooks-timeentry-staff", "member", "staff_id", ["first_name", " ", "last_name"], null, searchTerm);
		UIUtil.addDropdownEntry("freshbooks-timeentry-staff", "", "None", true);
		UIUtil.hideLoading('freshbooks','staff','-timeentry');
		$("freshbooks-timeentry-staff").enable();
	},

	loadClientList:function(resData){
		tot_pages = this.fetchMultiPages(resData, "clients", this.CLIENT_LIST_REQ, this.loadClientList)
		selectedClientNode = this.loadFreshbooksEntries(resData, "freshbooks-timeentry-clients", "client", "client_id", ["organization", " ", "(", "first_name", " ", "last_name", ")"], null, freshbooksBundle.reqEmail, tot_pages>1);
		UIUtil.sortDropdown("freshbooks-timeentry-clients");
		client_id = XmlUtil.getNodeValueStr(selectedClientNode, "client_id");
		UIUtil.hideLoading('freshbooks','clients','-timeentry');
		$("freshbooks-timeentry-clients").enable();
		this.clientChanged(client_id);
	},

	loadProjectList:function(resData) {
		tot_pages = this.fetchMultiPages(resData, "projects", this.PROJECT_LIST_REQ, this.loadProjectList)
		if (tot_pages > 1){
			this.mergePagedProjects(resData)
		}
		else{
			this.projectData=resData;
			this.loadProjects();
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
						on_success: success_fun.bind(this),
						on_failure: function(evt){
						}
					});
				}
			}
		}catch(e) {}
		return tot_pages;
	},

	mergePagedProjects: function(resData) {
		try{
			if(this.curr_page == 1)
				this.projectResults = "<projects>";

			resText = resData.responseText;
			projectPattern =  '<projects page="' + this.curr_page + '" per_page="100" pages="' + this.tot_pages + '" total="' + this.tot_items + '">';
			resText = resText.replace(projectPattern, "<projects>");
			projResults = resText.split("<projects>")[1];
			projResults = projResults.split("</projects>")[0];
			this.projectResults += projResults;

			if(this.curr_page == this.tot_pages){
				this.projectResults += "</projects>";
				this.projectData = XmlUtil.loadXMLString(this.projectResults);
				this.loadProjects();
			}

		}catch(e) {}
	},

	loadProjects: function(){
		UIUtil.hideLoading('freshbooks','projects','-timeentry');
		$("freshbooks-timeentry-projects").enable();		
		this.handleLoadProject();
	},

	loadTaskList:function(resData) {
		this.taskData = resData;
		if (this.timeEntryXml) {
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "task_id")
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		} else 
			searchTerm = Cookie.retrieve("fb_task_id")
		selectedTaskNode = this.loadFreshbooksEntries(this.taskData, "freshbooks-timeentry-tasks", "task", "task_id", ["name"], null, searchTerm||"");
		if(!selectedTaskNode) {
			UIUtil.addDropdownEntry("freshbooks-timeentry-tasks", "", "None");
		}
		UIUtil.hideLoading('freshbooks','tasks','-timeentry');

		$("freshbooks-timeentry-tasks").enable();
		$("freshbooks-timeentry-hours").enable();
		$("freshbooks-timeentry-notes").enable();
		$("freshbooks-timeentry-submit").enable();

		jQuery(".freshbooks_timetracking_widget").removeClass('still_loading');
	},

	staffChanged:function(staff_id) {
//		alert("staff changed "+ $("freshbooks-timeentry-staff").value);
		if (this.projectData != '') {
			this.handleLoadProject();
		}
	},

	clientChanged:function(client_id) {
		if (this.projectData != '') {
			this.handleLoadProject();
		}
	},

	handleLoadProject:function() {
		if (this.timeEntryXml) {
			// If timeEntryXml is populated then this time entry is already added in freshbooks.  So choose the correct client and project id in the drop down.
			project_id = searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "project_id")
			client_id = this.get_client_id(this.projectData, project_id);
			UIUtil.chooseDropdownEntry("freshbooks-timeentry-clients", client_id);
		} else {
			searchTerm = Cookie.retrieve("fb_project_id")
			client_id = $("freshbooks-timeentry-clients").value
		}
		staff_id = $("freshbooks-timeentry-staff").value;
		filterBy = {'client_id':client_id, 'staff,staff,staff_id': staff_id};
		selectedProjectNode = this.loadFreshbooksEntries(this.projectData, "freshbooks-timeentry-projects", "project", "project_id", ["name"], filterBy, searchTerm||"");
		if(!selectedProjectNode) {
			UIUtil.addDropdownEntry("freshbooks-timeentry-projects", "", "None");
		}
		project_id = XmlUtil.getNodeValueStr(selectedProjectNode, "project_id");
		this.projectChanged(project_id);
	},

	projectChanged:function(project_id) {
		this.requestTaskList(project_id)
		Cookie.update("fb_project_id", project_id);
	},

	requestTaskList:function(project_id_val) {
		jQuery(".freshbooks_timetracking_widget").addClass('still_loading');

		jQuery("#freshbooks-tasks-spinner").removeClass('hide');
		jQuery("#freshbooks-timeentry-tasks").addClass('hide');

		this.freshdeskWidget.request({
			body: this.TASK_LIST_REQ.evaluate({project_id:project_id_val}),
			content_type: "application/xml",
			method: "post", 
			on_success: this.loadTaskList.bind(this)
		});
	},

	taskChanged:function(task_id) {
		Cookie.update("fb_task_id", task_id);
	},

	validateInput:function() {

		var hoursSpent = parseFloat($("freshbooks-timeentry-hours").value);
		if(isNaN(hoursSpent)){
			alert("Enter valid value for hours.");
			return false;
		}
		if(!$("freshbooks-timeentry-projects").value){
			alert("Please select a project.");
			return false;
		}
		if(!$("freshbooks-timeentry-tasks").value){
			alert("Please select a task.");
			return false;
		}
		return true;
	},

	logTimeEntry:function(integratable_id) {
		if(integratable_id) this.freshdeskWidget.local_integratable_id = integratable_id;
		if (freshbooksBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(integratable_id,resultCallback) {
		if(integratable_id)
			this.freshdeskWidget.local_integratable_id = integratable_id;
		if (Freshdesk.NativeIntegration.freshbooksWidget.validateInput()) {
			var body = this.CREATE_TIMEENTRY_REQ.evaluate({
				staff_id: $("freshbooks-timeentry-staff").value,
				project_id: $("freshbooks-timeentry-projects").value,
				task_id: $("freshbooks-timeentry-tasks").value,
				notes: $("freshbooks-timeentry-notes").value,
				hours: $("freshbooks-timeentry-hours").value,
				date: new Date(jQuery('.executed_at').val()).toString("yyyy-MM-dd")
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					this.add_freshbooks_resource_in_db();
					if (resultCallback) {
						this.result_callback = resultCallback;
						resultCallback(evt);
					}
				}.bind(this)
			});
		}
		return false;
	},

	handleTimeEntrySuccess:function(resData) {
		resXml = resData.responseXML;
		if(!resXml) return;
		if (this.isRespSuccessful(resXml)) {
			var responses = XmlUtil.extractEntities(resXml,"response");
			if (responses.length > 0) {
				this.freshdeskWidget.remote_integratable_id = XmlUtil.getNodeValueStr(responses[0], "time_entry_id")
			}
		}
	},

	retrieveTimeEntry:function(resultCallback){
		if (freshbooksBundle.remote_integratable_id) {
			var body = this.RETRIEVE_TIMEENTRY_REQ.evaluate({
				time_entry_id: freshbooksBundle.remote_integratable_id
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				on_success: this.loadTimeEntry.bind(this)
			});
		}
	},

	// This method is for reusing same widget again and again in multiple time sheet entry forms.  So this will resets all the states of this form. 
	resetIntegratedResourceIds: function(integrated_resource_id, remote_integratable_id, local_integratable_id, is_delete_request) {
		freshbooksBundle.integrated_resource_id = integrated_resource_id
		freshbooksBundle.remote_integratable_id = remote_integratable_id
		this.freshdeskWidget.local_integratable_id = local_integratable_id
		this.freshdeskWidget.remote_integratable_id = remote_integratable_id
		if (!is_delete_request)
	   		if (freshbooksBundle.remote_integratable_id){
	   			jQuery('.freshbooks_timetracking_widget .app-logo input:checkbox').attr('checked',true);
                jQuery('.freshbooks_timetracking_widget .integration_container').toggle(jQuery('.freshbooks_timetracking_widget .app-logo input:checkbox').prop('checked'));
	   			this.retrieveTimeEntry();
	   		}
	   		else{
	   			jQuery('.freshbooks_timetracking_widget .app-logo input:checkbox').attr('checked',false);			 
                jQuery('.freshbooks_timetracking_widget .integration_container').toggle(jQuery('.freshbooks_timetracking_widget .app-logo input:checkbox').prop('checked'));
	   			this.resetTimeEntryForm();
	   		}
	},

	resetTimeEntryForm: function(){
		if(this.timeEntryXml) {

			  
			// Editing the existing entry. Select already associated entry in the drop-downs that are already loaded.
			time_entry_node = XmlUtil.extractEntities(this.timeEntryXml, "time_entry")
			if (time_entry_node.length > 0) {
				staff_id = XmlUtil.getNodeValueStr(time_entry_node[0], "staff_id");
				UIUtil.chooseDropdownEntry("freshbooks-timeentry-staff", staff_id);
				project_id = XmlUtil.getNodeValueStr(time_entry_node[0], "project_id");
				client_id = this.get_client_id(this.projectData, project_id);
				task_id = XmlUtil.getNodeValueStr(time_entry_node[0], "task_id");
				this.taskChanged(task_id);
				this.clientChanged(client_id);
				UIUtil.chooseDropdownEntry("freshbooks-timeentry-clients", client_id);
				UIUtil.chooseDropdownEntry("freshbooks-timeentry-tasks", task_id);
			}
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		} else {
			   
			// Do nothing. As this the form is going to be used for creating new entry, let the staff, client, project and task drop down be selected with the last selected entry itself. 
		}
		$("freshbooks-timeentry-hours").value = "";
		$("freshbooks-timeentry-notes").value = freshbooksBundle.freshbooksNote.escapeHTML();
		$("freshbooks-timeentry-notes").focus();
	},

	// Utility methods
	loadFreshbooksEntries:function(resData, dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm, keepOldEntries) {
		if(resData.responseXML == undefined)
			responseData = resData;
		else
			responseData = resData.responseXML;
		if(this.isRespSuccessful(responseData)){
			UIUtil.constructDropDown(responseData, 'xml', dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm, keepOldEntries);
		}
		return foundEntity;
	},

	isRespSuccessful:function(resStr){
		var resEntities = XmlUtil.extractEntities(resStr,"response");
		if(resEntities.length>0){
			var errorStr = XmlUtil.getNodeValueStr(resEntities[0],"error");
			if(errorStr != ""){
				alert("Freshbooks reports the below error: \n\n" + errorStr + "\n\nTry again after correcting the error or fixing the error manually.  If you can not do so, contact support.");
				return false;
			}
		}
		return true;
	},

	updateTimeEntryUsingIds:function(remote_integratable_id, hours, resultCallback) {
		if (remote_integratable_id) {
			var body = this.UPDATE_TIMEENTRY_ONLY_HOURS_REQ.evaluate({
				time_entry_id: remote_integratable_id,
				hours: hours+""
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					this.resetIntegratedResourceIds();
					if(resultCallback) resultCallback(evt);
				}.bind(this)
			});
		}
	},

	// Methods for external widgets use.
	updateTimeEntry:function(resultCallback){
		if (freshbooksBundle.remote_integratable_id) {
			if (Freshdesk.NativeIntegration.freshbooksWidget.validateInput()) {
				var body = this.UPDATE_TIMEENTRY_REQ.evaluate({
					time_entry_id: freshbooksBundle.remote_integratable_id,
					staff_id: $("freshbooks-timeentry-staff").value,
					project_id: $("freshbooks-timeentry-projects").value,
					task_id: $("freshbooks-timeentry-tasks").value,
					notes: $("freshbooks-timeentry-notes").value,
					hours: $("freshbooks-timeentry-hours").value,
					date: this.executed_date.toString("yyyy-MM-dd")
				});
				this.freshdeskWidget.request({
					body: body,
					content_type: "application/xml",
					method: "post",
					on_success: function(evt){
						this.handleTimeEntrySuccess(evt);
						this.resetIntegratedResourceIds();
						if(resultCallback) resultCallback(evt);
					}.bind(this)
				});
			}
		} else {
			alert('Freshbooks widget is not loaded properly. Please try again.');
		}
	},

	deleteTimeEntryUsingIds:function(integrated_resource_id, remote_integratable_id, resultCallback){
		if (remote_integratable_id) {
			var body = this.DELETE_TIMEENTRY_REQ.evaluate({
				time_entry_id: remote_integratable_id
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					this.delete_freshbooks_resource_in_db(integrated_resource_id, resultCallback);
					if(resultCallback) resultCallback(evt);
				}.bind(this)
			});
		}
	},

	deleteTimeEntry:function(resultCallback){
		if (freshbooksBundle.remote_integratable_id) {
			deleteTimeEntryUsingIds(freshbooksBundle.remote_integratable_id, freshbooksBundle.integrated_resource_id, resultCallback)
		} else {
			alert('Freshbooks widget is not loaded properly. Please delete the entry manually.');
		}
	},

	convertToInlineWidget:function() {
		$("freshbooks-timeentry-hours-label").hide();
		$("freshbooks-timeentry-notes-label").hide();
		$("freshbooks-timeentry-hours").hide();
		$("freshbooks-timeentry-notes").hide();
		$("freshbooks-timeentry-submit").hide();
	},

	updateNotesAndTimeSpent:function(notes, timeSpent, billable, executed_date) {
		$("freshbooks-timeentry-hours").value = timeSpent;
		$("freshbooks-timeentry-notes").value = (notes+"\n"+freshbooksBundle.freshbooksNote).escapeHTML();
		this.executed_date = new Date(executed_date);
	},

	// This is method needs to be called by the external time entry code to map the remote and local integrated resorce ids.
	set_timesheet_entry_id:function(integratable_id) {
		if (!freshbooksBundle.remote_integratable_id) {
			this.freshdeskWidget.local_integratable_id = integratable_id;
			this.add_freshbooks_resource_in_db();
		}
	},

	add_freshbooks_resource_in_db:function() {
		this.freshdeskWidget.create_integrated_resource(function(evt){
			resJ = evt.responseJSON
			if (resJ['status'] != 'error') {
				freshbooksBundle.integrated_resource_id = resJ['integrations_integrated_resource']['id'];
				freshbooksBundle.remote_integratable_id = resJ['integrations_integrated_resource']['remote_integratable_id'];
			} else {
				alter("Freshbooks: Error while associating the remote resource id with local integrated resource id in db.");
			}
			if (result_callback) 
				result_callback(evt);
			this.result_callback = null;
		}.bind(this));
	},

	delete_freshbooks_resource_in_db:function(integrated_resource_id, resultCallback){
		if (integrated_resource_id) {
			this.freshdeskWidget.delete_integrated_resource(integrated_resource_id);
			freshbooksBundle.integrated_resource_id = "";
			freshbooksBundle.remote_integratable_id = "";
		}
	},

	// private methods
	get_client_id: function(projectData, projectId){
		projectEntries = XmlUtil.extractEntities(projectData.responseXML, "project");
		var len = projectEntries.length;
		for (var i = 0; i < len; i++) {
			projectIdValue = XmlUtil.getNodeValueStr(projectEntries[i], "project_id");
			if(projectIdValue == projectId) {
				return XmlUtil.getNodeValueStr(projectEntries[i], "client_id");
			}
		}
	},

	get_time_entry_prop_value: function(timeEntryXml, fetchEntity) {
		time_entry_node = XmlUtil.extractEntities(timeEntryXml, "time_entry")
		if (time_entry_node.length > 0) 
			return XmlUtil.getNodeValueStr(time_entry_node[0], fetchEntity);
	}	
}


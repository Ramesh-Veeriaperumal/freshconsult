var FreshbooksWidget = Class.create();
FreshbooksWidget.prototype = {
	FRESHBOOKS_FORM:new Template('<form id="freshbooks-timeentry-form"><div class="field first"><label>Staff</label><select name="staff-id" id="freshbooks-timeentry-staff" onchange="freshbooksWidget.staffChanged(this.options[this.selectedIndex].value)" disabled class="full"></select> <div class="paddingloading" id="freshbooks-staff-spinner"></div></div><div class="field"><label>Client</label><select name="client-id" id="freshbooks-timeentry-clients" class="full" disabled onchange="freshbooksWidget.clientChanged(this.options[this.selectedIndex].value)"></select> <div class="paddingloading" id="freshbooks-clients-spinner"></div></div><div class="field"><label>Project</label><select class="full" name="project-id" id="freshbooks-timeentry-projects" onchange="freshbooksWidget.projectChanged(this.options[this.selectedIndex].value)" disabled></select> <div class="paddingloading" id="freshbooks-projects-spinner"></div></div><div class="field last"><label>Task</label><select class="full" disabled name="task-id" id="freshbooks-timeentry-tasks" onchange="freshbooksWidget.taskChanged(this.options[this.selectedIndex].value)"></select> <div class="paddingloading" id="freshbooks-tasks-spinner" style="display:none;" ></div></div><div class="field"><label id="freshbooks-timeentry-notes-label">Notes</label><textarea disabled name="notes" id="freshbooks-timeentry-notes" wrap="virtual">'+freshbooksBundle.freshbooksNote.escapeHTML()+'</textarea></div><div class="field"><label id="freshbooks-timeentry-hours-label">Hours</label><input type="text" disabled name="hours" id="freshbooks-timeentry-hours"></div><input type="submit" disabled id="freshbooks-timeentry-submit" value="Submit" onclick="freshbooksWidget.logTimeEntry($(\'freshbooks-timeentry-form\'));return false;"></form>'),
	STAFF_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="staff.list"></request>'),
	CLIENT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="client.list"> <per_page>250</per_page></request>'),
	PROJECT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="project.list"> <per_page>2000</per_page></request>'),
	TASK_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?> <request method="task.list" > <project_id>#{project_id}</project_id> </request>'),
	CREATE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.create"> <time_entry> <project_id>#{project_id}</project_id> <task_id>#{task_id}</task_id> <hours>#{hours}</hours> <notes><![CDATA[#{notes}]]></notes> <staff_id>#{staff_id}</staff_id> </time_entry></request>'),
	RETRIEVE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.get"> <time_entry_id>#{time_entry_id}</time_entry_id> </request>'),
	UPDATE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.update"> <time_entry> <time_entry_id>#{time_entry_id}</time_entry_id> <project_id>#{project_id}</project_id> <task_id>#{task_id}</task_id> <staff_id>#{staff_id}</staff_id> <hours>#{hours}</hours> <notes><![CDATA[#{notes}]]></notes> </time_entry></request>'),
	UPDATE_TIMEENTRY_ONLY_HOURS_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.update"> <time_entry> <time_entry_id>#{time_entry_id}</time_entry_id> <hours>#{hours}</hours> </time_entry></request>'),
	DELETE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.delete"> <time_entry_id>#{time_entry_id}</time_entry_id> </request>'),

	initialize:function(freshbooksBundle, loadInline){
		widgetInst = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.projectData = ""; init_reqs = []
		init_reqs = [null, {
			body: widgetInst.STAFF_LIST_REQ.evaluate({}),
			content_type: "application/xml",
			method: "post", 
			on_success: widgetInst.loadStaffList.bind(this),
			on_failure: function(evt){}
		}, {
			body: widgetInst.CLIENT_LIST_REQ.evaluate({}),
			content_type: "application/xml",
			method: "post", 
			on_success: widgetInst.loadClientList.bind(this)
		}, {
			body: widgetInst.PROJECT_LIST_REQ.evaluate({}),
			content_type: "application/xml",
			method: "post", 
			on_success: widgetInst.loadProjectList.bind(this),
			on_failure: function(evt){}
		}]
		if (freshbooksBundle.remote_integratable_id)
			init_reqs[0] = {
				body: widgetInst.RETRIEVE_TIMEENTRY_REQ.evaluate({
					time_entry_id: freshbooksBundle.remote_integratable_id
				}),
				content_type: "application/xml",
				method: "post", 
				on_success: widgetInst.loadTimeEntry.bind(this),
				on_failure: function(evt){}
			}
		freshbooksOptions = {
			application_id:freshbooksBundle.application_id,
			integratable_type:"timesheet",
			anchor: "freshbooks_widget",
			app_name:"Freshbooks",
			domain: $('freshbooks_widget').getAttribute('api_url').escapeHTML(),
			application_content: function() {
				return widgetInst.FRESHBOOKS_FORM.evaluate({});
			},
			application_resources: init_reqs
		};

		if (typeof(freshbooksBundle) != 'undefined' && freshbooksBundle.k) {
			freshbooksOptions.username = freshbooksBundle.k;
			freshbooksOptions.password = "x";
			this.freshdeskWidget = new Freshdesk.Widget(freshbooksOptions);
		} else {
			freshbooksOptions.login_content = function() {
				return '<form onsubmit="freshbooksWidget.login(this); return false;" class="form">' + '<label>Authentication Key</label><input type="password" id="username"/>' + '<input type="hidden" id="password" value="X"/>' + '<input type="submit" value="Login" id="submit">' + '</form>';
			};
			this.freshdeskWidget = new Freshdesk.Widget(freshbooksOptions);
		};
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
		$("freshbooks-timeentry-staff").enable();
	},

	loadClientList:function(resData){ 
		selectedClientNode = this.loadFreshbooksEntries(resData, "freshbooks-timeentry-clients", "client", "client_id", ["organization", " ", "(", "first_name", " ", "last_name", ")"], null, freshbooksBundle.reqEmail);
		client_id = XmlUtil.getNodeValueStr(selectedClientNode, "client_id");
		$("freshbooks-timeentry-clients").enable();
		this.clientChanged(client_id);
	},

	loadProjectList:function(resData) {
		this.projectData=resData;
		$("freshbooks-timeentry-projects").enable();		
		this.handleLoadProject();
	},

	loadTaskList:function(resData) {
		this.taskData = resData;
		if (this.timeEntryXml)
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "task_id")
		else
			searchTerm = Cookie.retrieve("fb_task_id")
		selectedTaskNode = this.loadFreshbooksEntries(this.taskData, "freshbooks-timeentry-tasks", "task", "task_id", ["name"], null, searchTerm||"");
		if(!selectedTaskNode) {
			UIUtil.addDropdownEntry("freshbooks-timeentry-tasks", "", "None");
		}
		$("freshbooks-timeentry-tasks").enable();
		$("freshbooks-timeentry-hours").enable();
		$("freshbooks-timeentry-notes").enable();
		$("freshbooks-timeentry-submit").enable();
	},

	staffChanged:function(staff_id) {
//		alert("staff changed "+ $("freshbooks-timeentry-staff").value);
	},

	clientChanged:function(client_id) {
		if (this.projectData != '') {
			this.handleLoadProject();
		}
	},

	handleLoadProject:function() {
		if (this.timeEntryXml) {
			// If timeEntryXml is populated then this already time entry added in freshbooks.  So choose the correct client and project id in the drop down.
			project_id = searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "project_id")
			client_id = this.get_client_id(this.projectData, project_id);
			UIUtil.chooseDropdownEntry("freshbooks-timeentry-clients", client_id);
		} else {
			searchTerm = Cookie.retrieve("fb_project_id")
			client_id = $("freshbooks-timeentry-clients").value
		}
		filterBy = {"client_id":client_id};
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
		this.freshdeskWidget.request({
			body: this.TASK_LIST_REQ.evaluate({project_id:project_id_val}),
			content_type: "application/xml",
			method: "post", 
			on_success: this.loadTaskList.bind(this)
		});
	},

	taskChanged:function(task_id) {
		task_id = $("freshbooks-timeentry-tasks").value;
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

	logTimeEntry:function() {
		if (freshbooksBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(resultCallback) {
		if (freshbooksWidget.validateInput()) {
			var body = this.CREATE_TIMEENTRY_REQ.evaluate({
				staff_id: $("freshbooks-timeentry-staff").value,
				project_id: $("freshbooks-timeentry-projects").value,
				task_id: $("freshbooks-timeentry-tasks").value,
				notes: $("freshbooks-timeentry-notes").value,
				hours: $("freshbooks-timeentry-hours").value
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
		resXml = resData.responseXML
		if (this.isRespSuccessful(resXml)) {
			var responses = XmlUtil.extractEntities(resXml,"response");
			if (responses.length > 0) {
				this.freshdeskWidget.remote_integratable_id = XmlUtil.getNodeValueStr(responses[0], "time_entry_id")
				this.resetTimeEntryForm();
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

	setIntegratedResourceIds: function(integrated_resource_id, remote_integratable_id, is_delete_request) {
		freshbooksBundle.integrated_resource_id = integrated_resource_id
		freshbooksBundle.remote_integratable_id = remote_integratable_id
		if (!is_delete_request)
	   		if (freshbooksBundle.remote_integratable_id)
	   			this.retrieveTimeEntry();
	   		else
	   			this.resetTimeEntryForm();
	},

	resetTimeEntryForm: function(){
		if(this.timeEntryXml) {
			// Editing the existing entry. Select already associated entry in the drop-downs that are already loaded.
			time_entry_node = XmlUtil.extractEntities(this.timeEntryXml, "time_entry")
			if (time_entry_node.length > 0) {
				staff_id = XmlUtil.getNodeValueStr(time_entry_node[0], "staff_id");
				project_id = XmlUtil.getNodeValueStr(time_entry_node[0], "project_id");
				client_id = this.get_client_id(this.projectData, project_id);
				UIUtil.chooseDropdownEntry("freshbooks-timeentry-staff", staff_id);
				UIUtil.chooseDropdownEntry("freshbooks-timeentry-clients", client_id);
				this.clientChanged(client_id);
			}
		} else {
			// Do nothing. As this the form is going to be used for creating new entry, let the staff, client, project and task drop down be selected with the last selected entry itself. 
		}
		$("freshbooks-timeentry-hours").value = "";
		$("freshbooks-timeentry-notes").value = freshbooksBundle.freshbooksNote.escapeHTML();
		$("freshbooks-timeentry-notes").focus();
	},

	// Utility methods
	loadFreshbooksEntries:function(resData, dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm) {
		if(this.isRespSuccessful(resData.responseXML)){
			UIUtil.constructDropDown(resData, dropDownBoxId, entityName, entityId, dispNames, filterBy, searchTerm);
		}
		return foundEntity;
	},

	isRespSuccessful:function(resStr){
		var resEntities = XmlUtil.extractEntities(resStr,"response");
		if(resEntities.length>0){
			var errorStr = XmlUtil.getNodeValueStr(resEntities[0],"error");
			if(errorStr != ""){
				alert("Freshbooks reports the below error: \n\n" + errorStr + "\n\nTry fixing the error manually.  Otherwise contact support.");
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
					if(resultCallback) resultCallback(evt);
				}.bind(this)
			});
		}
	},

	// Methods for external widgets use.
	updateTimeEntry:function(resultCallback){
		if (freshbooksBundle.remote_integratable_id) {
			if (freshbooksWidget.validateInput()) {
				var body = this.UPDATE_TIMEENTRY_REQ.evaluate({
					time_entry_id: freshbooksBundle.remote_integratable_id,
					staff_id: $("freshbooks-timeentry-staff").value,
					project_id: $("freshbooks-timeentry-projects").value,
					task_id: $("freshbooks-timeentry-tasks").value,
					notes: $("freshbooks-timeentry-notes").value,
					hours: $("freshbooks-timeentry-hours").value
				});
				this.freshdeskWidget.request({
					body: body,
					content_type: "application/xml",
					method: "post",
					on_success: function(evt){
						this.handleTimeEntrySuccess(evt);
						if(resultCallback) resultCallback(evt);
					}.bind(this)
				});
			}
		} else {
			alert('Freshbooks widget is not loaded properly. Please try again.');
		}
	},

	deleteTimeEntryUsingIds:function(integrated_resource_id, remote_integratable_id, resultCallback){
		this.setIntegratedResourceIds(integrated_resource_id, remote_integratable_id, true);
		this.deleteTimeEntry(resultCallback);
	},

	deleteTimeEntry:function(resultCallback){
		if (freshbooksBundle.remote_integratable_id) {
			var body = this.DELETE_TIMEENTRY_REQ.evaluate({
				time_entry_id: freshbooksBundle.remote_integratable_id
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					this.delete_freshbooks_resource_in_db(resultCallback);
					if(resultCallback) resultCallback(evt);
				}.bind(this)
			});
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

	updateNotesAndTimeSpent:function(notes, timeSpent, billable) {
		$("freshbooks-timeentry-hours").value = timeSpent;
		$("freshbooks-timeentry-notes").value = (notes+"\n"+freshbooksBundle.freshbooksNote).escapeHTML();
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
				console.log("Error while adding the integrated resource in db.");
			}
			if (result_callback) 
				result_callback(evt);
			this.result_callback = null;
		}.bind(this));
	},

	delete_freshbooks_resource_in_db:function(resultCallback){
		if (freshbooksBundle.integrated_resource_id) {
			this.freshdeskWidget.delete_integrated_resource(freshbooksBundle.integrated_resource_id);
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

freshbooksWidget = new FreshbooksWidget(freshbooksBundle, freshbooksinline);

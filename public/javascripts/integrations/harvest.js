var HarvestWidget = Class.create();
HarvestWidget.prototype= {
	LOGIN_FORM:new Template('<form onsubmit="harvestWidget.freshdeskWidget.login(this);if(harvestWidget.inline) harvestWidget.convertToInlineWidget();return false;"><div class="field first"><label>Username</label><input type="text" id="username"/></div><div class="field"><label>Password</label><input type="password" class="text" id="password"/></div><div class="field"><label><input type="checkbox" id="remember_me" checked value="true" />Remember me</label><input type="submit" class="btn" value="Login" id="submit"></div></form>'),
	HARVEST_FORM:new Template('<form id="harvest-timeentry-form" method="post"> <a href="javascript:void(0)" class="link" onclick="harvestWidget.freshdeskWidget.logout()">(Use different user)</a> <div class="field first"><label>Client</label><select name="client-id" id="harvest-timeentry-clients" onchange="harvestWidget.clientChanged(this.options[this.selectedIndex].value)"></select> </div><div class="field"> <label>Project</label><select name="request[project_id]" id="harvest-timeentry-projects" onchange="harvestWidget.projectChanged(this.options[this.selectedIndex].value)"></select> <div class="paddingloading" id="harvest-project-spinner" style="display:none;"></div> </div><div class="field"><label>Task</label><select disabled name="request[task_id]" id="harvest-timeentry-tasks" onchange="harvestWidget.taskChanged(this.options[this.selectedIndex].value)"></select> <div class="paddingloading" id="harvest-task-spinner" style="display:none;" ></div> </div><div class="field"><label id="harvest-timeentry-notes-label">Notes</label><textarea disabled name="request[notes]" id="harvest-timeentry-notes" wrap="virtual">'+harvestBundle.harvestNote.escapeHTML()+'</textarea></div><div class="field"> <label id="harvest-timeentry-hours-label">Hours</label><input type="text" disabled name="request[hours]" id="harvest-timeentry-hours"> </div> <div class="field"><label id="harvest-timeentry-billable-label"><input type="checkbox" id="harvest-timeentry-billable" checked value="true" />Billable</label> <input type="submit" disabled id="harvest-timeentry-submit" value="Submit" onclick="harvestWidget.logTimeEntry($(\'harvest-timeentry-form\'));return false;"></form>'),

	initialize:function(harvestBundle, loadInline){
		harvestWidget = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.projectData = "";
		this.taskData = "";
		this.inline = loadInline;
		var init_reqs = []
		init_reqs = [null, {
			resource: "clients",
			content_type: "application/xml",
			on_failure: harvestWidget.processFailure,
			on_success: harvestWidget.loadClient.bind(this)
		}, {
			resource: "projects",
			content_type: "application/xml",
			on_failure: function(evt){
			},
			on_success: harvestWidget.loadProject.bind(this)
		}, {
			resource: "tasks",
			content_type: "application/xml",
			on_failure: function(evt){
			},
			on_success: harvestWidget.loadTask.bind(this)
		}];
		if (harvestBundle.remote_integratable_id) 
			init_reqs[0] = {
				resource: "daily/show/"+harvestBundle.remote_integratable_id,
				content_type: "application/xml",
				on_failure: function(evt){
				},
				on_success: harvestWidget.loadTimeEntry.bind(this)
			}
		if(harvestBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				application_id:harvestBundle.application_id,
				integratable_type:"timesheet",
				anchor:"harvest_widget",
				app_name:"Harvest",
				domain:harvestBundle.domain + ".harvestapp.com",
				ssl_enabled:harvestBundle.ssl_enabled || "false",
				login_content: function(){
					return harvestWidget.LOGIN_FORM.evaluate({});
				},
				application_content: function(){
					return harvestWidget.HARVEST_FORM.evaluate({});
				},
				application_resources:init_reqs
			});
		}
		if(loadInline) this.convertToInlineWidget();
	},

	loadTimeEntry: function(resData) {
		if (resData) {
			this.timeEntryXml = resData.responseXML;
			this.resetTimeEntryForm();
		}
	},

	loadClient:function(resData) {
		selectedClientNode = UIUtil.constructDropDown(resData, "harvest-timeentry-clients", "client", "id", ["name"], null, Cookie.retrieve("har_client_id")||"");
		client_id = XmlUtil.getNodeValueStr(selectedClientNode, "id");
		this.clientChanged(client_id);
	},

	loadProject:function(resData) {
		this.projectData=resData;
		this.handleLoadProject();
	},

	handleLoadProject:function() {
		console.log("Harest handleLoadProject.");
		if (this.timeEntryXml) {
			// If timeEntryXml is populated then this already time entry added in harvest.  So choose the correct client and project id in the drop down.
			project_id = searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "project_id")
			client_id = this.get_client_id(this.projectData, project_id);
			UIUtil.chooseDropdownEntry("harvest-timeentry-clients", client_id);
		} else {
			searchTerm = Cookie.retrieve("har_project_id")
			client_id = $("harvest-timeentry-clients").value
		}
		filterBy = null
		if(client_id) filterBy = {"client-id":client_id};
		selectedProjectNode = UIUtil.constructDropDown(this.projectData, "harvest-timeentry-projects", "project", "id", ["name"], filterBy, searchTerm||"");
		if(!selectedProjectNode) {
			UIUtil.addDropdownEntry("harvest-timeentry-projects", "", "None");
		}
		project_id = XmlUtil.getNodeValueStr(selectedProjectNode, "id");
		this.projectChanged(project_id);
	},

	loadTask:function(resData) {
		this.taskData=resData;
		this.handleLoadTask();
	},

	handleLoadTask:function() {
		console.log("Harest handleLoadTask.");
		if (this.timeEntryXml)
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "task_id")
		else
			searchTerm = Cookie.retrieve("har_task_id")
		selectedTaskNode = UIUtil.constructDropDown(this.taskData, "harvest-timeentry-tasks", "task", "id", ["name"], null, Cookie.retrieve("har_task_id")||"");
		if(!selectedTaskNode) {
			UIUtil.addDropdownEntry("harvest-timeentry-tasks", "", "None");
		}
		$("harvest-timeentry-tasks").enable();
		$("harvest-timeentry-hours").enable();
		$("harvest-timeentry-notes").enable();
		$("harvest-timeentry-billable").enable();
		$("harvest-timeentry-submit").enable();
	},

	clientChanged:function(client_id) {
		if(this.projectData != '') {
			this.handleLoadProject();
		}
		Cookie.update("har_client_id", client_id);
	},

	projectChanged:function(project_id) {
		if(this.taskData != '') {
			this.handleLoadTask();
		}
		Cookie.update("har_project_id", project_id);
	},

	taskChanged:function(task_id) {
		Cookie.update("har_task_id", task_id);
	},

	validateInput:function() {
		var hoursSpent = parseFloat($("harvest-timeentry-hours").value);
		if(isNaN(hoursSpent)){
			alert("Enter valid value for hours.");
			return false;
		}
	},

	logTimeEntry:function() {
		if (harvestBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(resultCallback) {
		alert($("harvest-timeentry-billable").value);
		if (this.validateInput()) {
			this.freshdeskWidget.request({
				entity_name: "request",
				"request[project_id]": $("harvest-timeentry-projects").value,
				"request[task_id]": $("harvest-timeentry-tasks").value,
				"request[notes]": $("harvest-timeentry-notes").value,
				"request[hours]": $("harvest-timeentry-hours").value,
				"request[billable]": $("harvest-timeentry-billable").value,
				resource: "daily/add",
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					harvestWidget.handleTimeEntrySuccess(evt);
					harvestWidget.add_harvest_resource_in_db();
					if (resultCallback) {
						this.result_callback = resultCallback;
						resultCallback(evt);
					}
				}.bind(this),
				on_failure: harvestWidget.processFailure
			});
		}
		return false;
	}, 

	handleTimeEntrySuccess:function(resData) {
		resXml = resData.responseXML
		var dayEntries = XmlUtil.extractEntities(resXml,"day_entry");
		if(dayEntries.length>0){
			this.freshdeskWidget.remote_integratable_id = XmlUtil.getNodeValueStr(dayEntries[0],"id");
			this.resetTimeEntryForm();
		}
	},

	retrieveTimeEntry:function(resultCallback){
		if (harvestBundle.remote_integratable_id) {
			this.freshdeskWidget.request({
				resource: "daily/show/"+harvestBundle.remote_integratable_id,
				content_type: "application/xml",
				on_success: harvestWidget.loadTimeEntry.bind(this),
				on_failure: harvestWidget.processFailure
			});
		}
	},
 
	setIntegratedResourceIds: function(integrated_resource_id, remote_integratable_id, is_delete_request) {
		harvestBundle.integrated_resource_id = integrated_resource_id
		harvestBundle.remote_integratable_id = remote_integratable_id
		if (!is_delete_request)
			if (harvestBundle.remote_integratable_id)
				this.retrieveTimeEntry();
			else
				this.resetTimeEntryForm();
	},

	resetTimeEntryForm: function(){
		if(this.timeEntryXml) {
			// Editing the existing entry. Select already associated entry in the drop-downs that are already loaded.
			time_entry_node = XmlUtil.extractEntities(this.timeEntryXml, "day_entry")
			if (time_entry_node.length > 0) {
				project_id = XmlUtil.getNodeValueStr(time_entry_node[0], "project_id");
				client_id = this.get_client_id(this.projectData, project_id);
				UIUtil.chooseDropdownEntry("harvest-timeentry-clients", client_id);
				this.clientChanged(client_id);  // This will take care of changing the project selection.
				task_id = XmlUtil.getNodeValueStr(time_entry_node[0], "task_id");
				UIUtil.chooseDropdownEntry("harvest-timeentry-tasks", task_id);
			}
		} else {
			// Do nothing. As this the form is going to be used for creating new entry, let the staff, client, project and task drop down be selected with the last selected entry itself. 
		}
		$("harvest-timeentry-hours").value = "";
		$("harvest-timeentry-billable").selected = true
		$("harvest-timeentry-notes").value = harvestBundle.harvestNote.escapeHTML();
		$("harvest-timeentry-notes").focus();
	},

	processFailure:function(evt) {
		if (evt.status == 401) {
			alert("Username or password is incorrect.");
			harvestWidget.freshdeskWidget.display_login();
		} else if (evt.status == 404) {
			alert("Selected project and/or task is no longer assigned to the logged-in user.");
		} else {
			alert(evt.responseText);
		}
	},
	
	// Methods for external widgets use.
	updateTimeEntry:function(resultCallback){
		if (harvestBundle.remote_integratable_id) {
			if (this.validateInput()) {
				this.freshdeskWidget.request({
					entity_name: "request",
					"request[project_id]": $("harvest-timeentry-projects").value,
					"request[task_id]": $("harvest-timeentry-tasks").value,
					"request[notes]": $("harvest-timeentry-notes").value,
					"request[billable]": $("harvest-timeentry-billable").value,
					"request[hours]": $("harvest-timeentry-hours").value,
					resource: "daily/update/"+harvestBundle.remote_integratable_id,
					content_type: "application/xml",
					method: "post",
					on_success: function(evt){
						harvestWidget.handleTimeEntrySuccess(evt);
						if(resultCallback) resultCallback(evt);
					}.bind(this),
					on_failure: harvestWidget.processFailure
				});
			}
		} else {
			alert('Harvest widget is not loaded properly. Please try again.');
		}
	},

	deleteTimeEntryUsingIds:function(integrated_resource_id, remote_integratable_id, resultCallback){
		this.setIntegratedResourceIds(integrated_resource_id, remote_integratable_id, true);
		this.deleteTimeEntry(resultCallback);
	},

	deleteTimeEntry:function(resultCallback){
		if (harvestBundle.remote_integratable_id) {
			this.freshdeskWidget.request({
				resource: "daily/delete/"+harvestBundle.remote_integratable_id,
				content_type: "application/xml",
				method: "delete",
				on_success: function(evt){
					harvestWidget.handleTimeEntrySuccess(evt);
					if(resultCallback) resultCallback(evt);
				}.bind(this),
				on_failure: harvestWidget.processFailure
			});
		} else {
			alert('Harvest widget is not loaded properly. Please delete the entry manually.');
		}
	},

	convertToInlineWidget:function() {
		if ($("harvest-timeentry-hours-label")) {
			$("harvest-timeentry-hours-label").hide();
			$("harvest-timeentry-notes-label").hide();
			$("harvest-timeentry-billable-label").hide();
			$("harvest-timeentry-hours").hide();
			$("harvest-timeentry-notes").hide();
			$("harvest-timeentry-billable").hide();
			$("harvest-timeentry-submit").hide();
		}
	},

	updateNotesAndTimeSpent:function(notes, timeSpent, billable) {
		$("harvest-timeentry-hours").value = timeSpent;
		$("harvest-timeentry-notes").value = (notes+"\n"+harvestBundle.harvestNote).escapeHTML();
		$("harvest-timeentry-billable").value = billable;
	},

	// This is method needs to be called by the external time entry code to map the remote and local integrated resorce ids.
	set_timesheet_entry_id:function(integratable_id) {
		if (!harvestBundle.remote_integratable_id) {
			this.freshdeskWidget.local_integratable_id = integratable_id;
			this.add_harvest_resource_in_db();
		}
	},

	add_harvest_resource_in_db:function() {
		this.freshdeskWidget.create_integrated_resource(function(evt){
			resJ = evt.responseJSON
			if (resJ['status'] != 'error') {
				harvestBundle.integrated_resource_id = resJ['integrations_integrated_resource']['id'];
				harvestBundle.remote_integratable_id = resJ['integrations_integrated_resource']['remote_integratable_id'];
			} else {
				console.log("Error while adding the integrated resource in db.");
			}
			if (result_callback) 
				result_callback(evt);
			this.result_callback = null;
		}.bind(this));
	},

	delete_harvest_resource_in_db:function(resultCallback){
		if (harvestBundle.integrated_resource_id) {
			this.freshdeskWidget.delete_integrated_resource(harvestBundle.integrated_resource_id);
			harvestBundle.integrated_resource_id = "";
			harvestBundle.remote_integratable_id = "";
		}
	},

	// private methods
	get_client_id: function(projectData, projectId){
		projectEntries = XmlUtil.extractEntities(projectData.responseXML, "project");
		var len = projectEntries.length;
		for (var i = 0; i < len; i++) {
			projectIdValue = XmlUtil.getNodeValueStr(projectEntries[i], "id");
			if(projectIdValue == projectId) {
				return XmlUtil.getNodeValueStr(projectEntries[i], "client-id");
			}
		}
	},
 
	get_time_entry_prop_value: function(timeEntryXml, fetchEntity) {
		time_entry_node = XmlUtil.extractEntities(timeEntryXml, "day_entry")
		if (time_entry_node.length > 0) 
			return XmlUtil.getNodeValueStr(time_entry_node[0], fetchEntity);
	}
}

harvestWidget = new HarvestWidget(harvestBundle, harvestinline);

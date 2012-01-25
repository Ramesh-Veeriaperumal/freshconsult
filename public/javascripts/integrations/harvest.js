var HarvestWidget = Class.create();
HarvestWidget.prototype= {
	LOGIN_FORM:new Template('<form onsubmit="harvestWidget.freshdeskWidget.login(this);return false;"><label>Username</label><input type="text" id="username"/><label>Password</label><input type="password" id="password"/><br/><input type="checkbox" id="remember_me" checked value="true">Remember this agent</input><br/><input type="submit" value="Login" id="submit"></form>'),
	HARVEST_FORM:new Template('<form id="harvest-timeentry-form" method="post"> <span class="link" style="font-weight:normal;margin-left:20px;" onclick="harvestWidget.freshdeskWidget.logout()">(Use different user)</span> <label>Client</label><select name="client-id" id="harvest-timeentry-clients" onchange="harvestWidget.clientChanged(this.options[this.selectedIndex].value)"></select> <br/> <label>Project</label><select name="request[project_id]" id="harvest-timeentry-projects" onchange="harvestWidget.projectChanged(this.options[this.selectedIndex].value)"></select> <div class="paddingloading" id="harvest-project-spinner" style="display:none;"></div> <label>Task</label><select disabled name="request[task_id]" id="harvest-timeentry-tasks" onchange="harvestWidget.taskChanged(this.options[this.selectedIndex].value)"></select> <div class="paddingloading" id="harvest-task-spinner" style="display:none;" ></div> <label id="harvest-timeentry-notes-label">Notes</label><textarea disabled name="request[notes]" id="harvest-timeentry-notes" wrap="virtual" style="width:190px; height: 50px;">'+harvestBundle.harvestNote.escapeHTML()+'</textarea> <label id="harvest-timeentry-hours-label">Hours</label><input type="text" disabled name="request[hours]" id="harvest-timeentry-hours" style="width:50px"> <br/><input type="submit" disabled id="harvest-timeentry-submit" style="margin-top: 10px;" value="Submit" onclick="harvestWidget.logTimeEntry($(\'harvest-timeentry-form\'));return false;"></form>'),

	initialize:function(harvestBundle, loadInline){
		harvestWidget = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.projectData = "";
		this.taskData = "";
		var init_reqs = []
		if (!loadInline || harvestBundle.remote_integratable_id == '') {
			init_reqs = [{
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
		}
		if(harvestBundle.domain) {
			this.freshdeskWidget = new Freshdesk.Widget({
				application_id:harvestBundle.application_id,
				integratable_type:"timesheet",
				anchor:"harvest_widget",
				domain:harvestBundle.domain,
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

	loadClient:function(resData) {
		selectedClientNode = UIUtil.constructDropDown(resData, "harvest-timeentry-clients", "client", "id", ["name"], null, Cookie.get("har_client_id")||"");
		client_id = XmlUtil.getNodeValueStr(selectedClientNode, "id");
		this.clientChanged(client_id);
	},

	loadProject:function(resData) {
		this.projectData=resData;
		this.handleLoadProject(resData);
	},

	handleLoadProject:function() {
		console.log("Harest handleLoadProject.");
		filterBy = {"client-id":$("harvest-timeentry-clients").value};
		selectedProjectNode = UIUtil.constructDropDown(this.projectData, "harvest-timeentry-projects", "project", "id", ["name"], filterBy, Cookie.get("har_project_id")||"");
		project_id = XmlUtil.getNodeValueStr(selectedProjectNode, "id");
		this.projectChanged(project_id);
	},

	loadTask:function(resData) {
		this.taskData=resData;
		this.handleLoadTask(resData);
	},

	handleLoadTask:function() {
		console.log("Harest handleLoadTask.");
		filterBy = {"project-id":$("harvest-timeentry-projects").value};
		UIUtil.constructDropDown(this.taskData, "harvest-timeentry-tasks", "task", "id", ["name"], null, Cookie.get("har_task_id")||"");
		$("harvest-timeentry-tasks").enable();
		$("harvest-timeentry-hours").enable();
		$("harvest-timeentry-notes").enable();
		$("harvest-timeentry-submit").enable();
	},

	clientChanged:function(client_id) {
		if(this.projectData != '') {
			this.handleLoadProject();
		}
		Cookie.set("har_client_id", client_id);
	},

	projectChanged:function(project_id) {
		if(this.taskData != '') {
			this.handleLoadTask();
		}
		Cookie.set("har_project_id", project_id);
	},

	taskChanged:function(task_id) {
		Cookie.set("har_task_id", task_id);
	},

	validateInput:function() {
		var hoursSpent = parseFloat($("harvest-timeentry-hours").value);
		if(isNaN(hoursSpent)){
			alert("Enter valid value for hours.");
			return false;
		}
		return true;
	},

	logTimeEntry:function() {
		if (harvestBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(resultCallback) {
		if (this.validateInput()) {
			this.freshdeskWidget.request({
				entity_name: "request",
				"request[project_id]": $("harvest-timeentry-projects").value,
				"request[task_id]": $("harvest-timeentry-tasks").value,
				"request[notes]": $("harvest-timeentry-notes").value,
				"request[hours]": $("harvest-timeentry-hours").value,
				resource: "daily/add",
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					harvestWidget.handleTimeEntrySuccess(evt);
					if (resultCallback) {
						this.result_callback = resultCallback;
						resultCallback(evt);
					}
					harvestWidget.add_harvest_resource_in_db();
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
		}
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
					"request[notes]": $("harvest-timeentry-notes").value,
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
			alert('Harvest widget is not loaded properly. Please try again.');
		}
	},

	convertToInlineWidget:function() {
		if (harvestBundle.remote_integratable_id) {
			$("harvest-timeentry-form").hide();
		} else {
			$("harvest-timeentry-hours-label").hide();
			$("harvest-timeentry-notes-label").hide();
			$("harvest-timeentry-hours").hide();
			$("harvest-timeentry-notes").hide();
			$("harvest-timeentry-submit").hide();
		}
	},

	updateNotesAndTimeSpent:function(notes, timeSpent) {
		$("harvest-timeentry-hours").value = timeSpent;
		$("harvest-timeentry-notes").value = (notes+"\n"+harvestBundle.harvestNote).escapeHTML();
	},

	set_timesheet_entry_id:function(integratable_id) {
		if(integratable_id != null) this.freshdeskWidget.local_integratable_id = integratable_id;
		this.add_harvest_resource_in_db();
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
	}
}

harvestWidget = new HarvestWidget(harvestBundle);

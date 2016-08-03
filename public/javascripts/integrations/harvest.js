var HarvestWidget = Class.create();
HarvestWidget.prototype= {
	LOGIN_FORM:new Template('<form onsubmit="harvestWidget.login_form(this); return false;"><div class="field first"><label>Username</label><input type="text" id="username"/></div><div class="field"><label>Password</label><input type="password" class="text" id="password"/></div><div class="field"><input type="submit" class="btn" value="Login" id="submit"></div></form>'),
	HARVEST_FORM:new Template('<form id="harvest-timeentry-form" method="post"> <a href="javascript:void(0)" class="link" onclick="harvestWidget.freshdeskWidget.display_login()">(Use different user)</a> <div class="field first"><label>Client</label><select name="client-id" id="harvest-timeentry-clients" onchange="harvestWidget.clientChanged(this.options[this.selectedIndex].value)" class="full hide"></select> <div class="loading-fb" id="harvest-clients-spinner"></div></div><div class="field"> <label>Project</label><select name="request[project_id]" id="harvest-timeentry-projects" onchange="harvestWidget.projectChanged(this.options[this.selectedIndex].value)" class="full hide"></select> <div class="loading-fb" id="harvest-projects-spinner"></div> </div><div class="field"><label>Task</label><select disabled name="request[task_id]" id="harvest-timeentry-tasks" onchange="harvestWidget.taskChanged(this.options[this.selectedIndex].value)" class="full hide"></select> <div class="loading-fb" id="harvest-tasks-spinner" ></div> </div><div class="field"><label id="harvest-timeentry-notes-label">Notes</label><textarea disabled name="request[notes]" id="harvest-timeentry-notes" wrap="virtual">'+jQuery('#harvest-note').html().escapeHTML()+'</textarea></div><div class="field"> <label id="harvest-timeentry-hours-label">Hours</label><input type="text" disabled name="request[hours]" id="harvest-timeentry-hours"> </div> <input type="submit" disabled id="harvest-timeentry-submit" value="Submit" onclick="harvestWidget.logTimeEntry($(\'harvest-timeentry-form\'));return false;"></form>'),

	initialize:function(harvestBundle, loadInline){
		harvestWidget = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.projectData = ""; this.executed_date = new Date();
		this.taskData = "";
		this.inline = loadInline;
		harvestBundle.harvestNote = jQuery('#harvest-note').html();
		var init_reqs = [];
		init_reqs = [null, {
			rest_url: "daily",
			content_type: "application/xml",
			on_failure: harvestWidget.processFailure,
			on_success: harvestWidget.loadDaily.bind(this)
		}];
		if (harvestBundle.remote_integratable_id) 
			init_reqs[0] = {
				rest_url: "daily/show/"+harvestBundle.remote_integratable_id,
				content_type: "application/xml",
				on_failure: function(evt){
				},
				on_success: harvestWidget.loadTimeEntry.bind(this)
			}
		if(harvestBundle.domain) {
			//removing the cookie setting impulsively.
			Cookie.remove("harvest_widget_username");
			Cookie.remove("harvest_widget_password");
			this.freshdeskWidget = new Freshdesk.Widget({
				app_name:"Harvest",
				auth_type:"NoAuth",
				use_server_password: "true",
				application_id:harvestBundle.application_id,
				integratable_type:"timesheet",
				username: harvestBundle.current_user,
				domain:harvestBundle.domain,
				ssl_enabled:harvestBundle.ssl_enabled || "true",
				login_html: function(){
					return harvestWidget.LOGIN_FORM.evaluate({});
				},
				application_html: function(){
					return harvestWidget.HARVEST_FORM.evaluate({});
				},
				init_requests:init_reqs
			});
		}
		if(loadInline) this.convertToInlineWidget();
	},
	login_form: function(formData){
		userData = {'username':formData.username.value,'password': Base64.encode(formData.password.value),'app_name':'harvest'}
		url="/integrations/user_credentials";
		jQuery.ajax({
  			type: "POST",
  			url: url,
				data: userData,
			}).done(function(){	
						harvestWidget.freshdeskWidget.login(formData);
						if(harvestWidget.inline) {
							harvestWidget.convertToInlineWidget();
						}
					}).fail(function(){
								console.log('failed to update user credentials for harvest.');
							});
	},
	loadTimeEntry: function(resData) {
		if (resData) {
			this.timeEntryXml = resData.responseXML;
			this.resetTimeEntryForm();
		}
	},

	loadDaily:function(resData) {
		clientData = []
		this.projectData = resData.responseXML
		this.taskData = {}
		project_list = XmlUtil.extractEntities(this.projectData, "project")
		for(var i=0;i<project_list.length;i++) {
			proj_node = project_list[i];
			proj_id = XmlUtil.getNodeValue(proj_node, "id")
			client_name = XmlUtil.getNodeValue(proj_node, "client");
			matched = false
			for(var j=0;j<clientData.length;j++)
				if (clientData[j]["id"] == client_name) matched = true;
			if (!matched) clientData.push({"id":client_name, "name":client_name});
			task_list = XmlUtil.extractEntities(proj_node, "tasks");
			this.taskData[proj_id] = task_list[0]
		}
		this.clientData = {"client": clientData}
		this.handleLoadClient(); //This will take of progressively calling handleLoadProject and handleLoadTask.
	},

	handleLoadClient:function() {
		selectedClientNode = UIUtil.constructDropDown(this.clientData, 'hash', "harvest-timeentry-clients", "client", "id", ["name"], null, Cookie.retrieve("har_client_id")||"");
		UIUtil.sortDropdown("harvest-timeentry-clients");
		client_id = selectedClientNode["id"];
		this.clientChanged(client_id);
		UIUtil.hideLoading('harvest','clients','-timeentry');
	},

	handleLoadProject:function() {
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
		if(client_id) filterBy = {"client":client_id};
		selectedProjectNode = UIUtil.constructDropDown(this.projectData, "xml", "harvest-timeentry-projects", "project", "id", ["name"], filterBy, searchTerm||"");
		if(!selectedProjectNode) {
			UIUtil.addDropdownEntry("harvest-timeentry-projects", "", "None");
		}
		project_id = XmlUtil.getNodeValueStr(selectedProjectNode, "id");
		this.projectChanged(project_id);
		UIUtil.hideLoading('harvest','projects','-timeentry');
	},

	handleLoadTask:function() {
		if (this.timeEntryXml) {
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, "task_id")
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		}
		else 
			searchTerm = Cookie.retrieve("har_task_id")
		project_id = $("harvest-timeentry-projects").value
		selectedTaskNode = UIUtil.constructDropDown(this.taskData[project_id], "xml", "harvest-timeentry-tasks", "task", "id", ["name"], null, Cookie.retrieve("har_task_id")||"");
		if(!selectedTaskNode) {
			UIUtil.addDropdownEntry("harvest-timeentry-tasks", "", "None");
		}
		$("harvest-timeentry-tasks").enable();
		$("harvest-timeentry-hours").enable();
		$("harvest-timeentry-notes").enable();
		$("harvest-timeentry-submit").enable();
		UIUtil.hideLoading('harvest','tasks','-timeentry');

		jQuery(".harvest_timetracking_widget").removeClass('still_loading');
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

		if ($("harvest-timeentry-hours")) {
			var hoursSpent = $("harvest-timeentry-hours").value
			if (hoursSpent != "") {
				hoursSpent = parseFloat(hoursSpent);
			}
			
			if (isNaN(hoursSpent)) {
				alert("Enter valid value for hours.");
				return false;
			}
			return true;
		} else {
			alert("Please login to harvest.");
			return false;
		}
	},

	logTimeEntry:function(integratable_id) {
		if(integratable_id)
			this.freshdeskWidget.local_integratable_id = integratable_id;
		if (harvestBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(integratable_id,resultCallback) {
		if(integratable_id)
			this.freshdeskWidget.local_integratable_id = integratable_id;
		if (this.validateInput()) {
			this.freshdeskWidget.request({
				entity_name: "request",
				"request[project_id]": $("harvest-timeentry-projects").value,
				"request[task_id]": $("harvest-timeentry-tasks").value,
				"request[notes]": $("harvest-timeentry-notes").value,
				"request[hours]": $("harvest-timeentry-hours").value,
				"request[spent_at]": new Date(jQuery('#executed_at_new').val()).toString("ddd, dd MMM yyyy"),
				rest_url: "daily/add",
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
		resXml = resData.responseXML;
		if(!resXml) return;
		var dayEntries = XmlUtil.extractEntities(resXml,"day_entry");
		if(dayEntries.length>0){
			this.freshdeskWidget.remote_integratable_id = XmlUtil.getNodeValueStr(dayEntries[0],"id");
			this.resetTimeEntryForm();
		}	
	},

	retrieveTimeEntry:function(resultCallback){
		if (harvestBundle.remote_integratable_id) {
			this.freshdeskWidget.request({
				rest_url: "daily/show/"+harvestBundle.remote_integratable_id,
				content_type: "application/xml",
				on_success: harvestWidget.loadTimeEntry.bind(this),
				on_failure: harvestWidget.processFailure
			});
		}
	},
 
	resetIntegratedResourceIds: function(integrated_resource_id, remote_integratable_id, local_integratable_id, is_delete_request) {
		harvestBundle.integrated_resource_id = integrated_resource_id;
		harvestBundle.remote_integratable_id = remote_integratable_id;
		this.freshdeskWidget.local_integratable_id = local_integratable_id;
		this.freshdeskWidget.remote_integratable_id = remote_integratable_id;
		if (!is_delete_request){
			if (harvestBundle.remote_integratable_id){
				  jQuery('.harvest_timetracking_widget .app-logo input:checkbox').prop('checked',true);
                  jQuery('.harvest_timetracking_widget .integration_container').toggle(jQuery('.harvest_timetracking_widget .app-logo input:checkbox').prop('checked'));	 
				  this.retrieveTimeEntry();
				}
			else{
				 jQuery('.harvest_timetracking_widget .app-logo input:checkbox').prop('checked',false);
                 jQuery('.harvest_timetracking_widget .integration_container').toggle(jQuery('.harvest_timetracking_widget .app-logo input:checkbox').prop('checked'));
				 this.resetTimeEntryForm();
				}
		}
	},

	resetTimeEntryForm: function(){
		if(this.timeEntryXml) {
			time_entry_node = XmlUtil.extractEntities(this.timeEntryXml, "day_entry")
			if (time_entry_node.length > 0) {
				project_id = XmlUtil.getNodeValueStr(time_entry_node[0], "project_id");
				client_id = this.get_client_id(this.projectData, project_id);
				UIUtil.chooseDropdownEntry("harvest-timeentry-clients", client_id);
				this.clientChanged(client_id);  // This will take care of changing the project selection.
				task_id = XmlUtil.getNodeValueStr(time_entry_node[0], "task_id");
				UIUtil.chooseDropdownEntry("harvest-timeentry-tasks", task_id);
			}
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		} else {
			     // Do nothing. As this the form is going to be used for creating new entry, let the staff, client, project and task drop down be selected with the last selected entry itself.  
         }

		if ($("harvest-timeentry-hours")) {
			$("harvest-timeentry-hours").value = "";
			$("harvest-timeentry-notes").value = harvestBundle.harvestNote.escapeHTML();
			$("harvest-timeentry-notes").focus();
		}
	},

	processFailure:function(evt) {
		if (evt.status == 401) {
			alert("Username or password is incorrect for Harvest");
			harvestWidget.freshdeskWidget.display_login();
		} else if (evt.status == 404) {
			alert("Selected project and/or task is no longer assigned to the logged-in user.");
		} else {
			alert("Problem in connecting to Harvest. Response code: " + evt.status);
		}
	},

	updateTimeEntryUsingIds:function(remote_integratable_id, hours, resultCallback) {
		if (remote_integratable_id) {
			this.freshdeskWidget.request({
				entity_name: "request",
				"request[hours]": hours+"",
				rest_url: "daily/update/"+remote_integratable_id,
				content_type: "application/xml",
				method: "post",
				on_success: function(evt){
					harvestWidget.handleTimeEntrySuccess(evt);
					this.resetIntegratedResourceIds();
					if(resultCallback) resultCallback(evt);
				}.bind(this),
				on_failure: harvestWidget.processFailure
			});
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
					"request[hours]": $("harvest-timeentry-hours").value,
					"request[spent_at]": this.executed_date.toString("ddd, dd MMM yyyy"),
					rest_url: "daily/update/"+harvestBundle.remote_integratable_id,
					content_type: "application/xml",
					method: "post",
					on_success: function(evt){
						this.resetIntegratedResourceIds();
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
		if (remote_integratable_id) {
			this.freshdeskWidget.request({
				rest_url: "daily/delete/"+remote_integratable_id,
				content_type: "application/xml",
				method: "delete",
				on_success: function(evt){
					harvestWidget.handleTimeEntrySuccess(evt);
					this.delete_harvest_resource_in_db(integrated_resource_id, resultCallback);
					if(resultCallback) resultCallback(evt);
				}.bind(this),
				on_failure: harvestWidget.processFailure
			});
		}
	},

	deleteTimeEntry:function(resultCallback){
		if (harvestBundle.remote_integratable_id) {
			deleteTimeEntryUsingIds(harvestBundle.remote_integratable_id, harvestBundle.integrated_resource_id, resultCallback);
		} else {
			alert('Harvest widget is not loaded properly. Please delete the entry manually.');
		}
	},

	convertToInlineWidget:function() {
		if ($("harvest-timeentry-hours-label")) {
			$("harvest-timeentry-hours-label").hide();
			$("harvest-timeentry-notes-label").hide();
			$("harvest-timeentry-hours").hide();
			$("harvest-timeentry-notes").hide();
			$("harvest-timeentry-submit").hide();
		}
	},

	updateNotesAndTimeSpent:function(notes, timeSpent, billable, executed_date) {
		$("harvest-timeentry-hours").value = timeSpent;
		$("harvest-timeentry-notes").value = (notes+"\n"+harvestBundle.harvestNote).escapeHTML();
		this.executed_date = new Date(executed_date);
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
				alter("Harvest: Error while associating the remote resource id with local integrated resource id in db.");
			}
			if (result_callback) 
				result_callback(evt);
			this.result_callback = null;
		}.bind(this));
	},

	delete_harvest_resource_in_db:function(integrated_resource_id, resultCallback){
		if (integrated_resource_id) {
			this.freshdeskWidget.delete_integrated_resource(integrated_resource_id);
			harvestBundle.integrated_resource_id = "";
			harvestBundle.remote_integratable_id = "";
		}
	},

	// private methods
	get_client_id: function(projectData, projectId){
		projectEntries = XmlUtil.extractEntities(projectData, "project");
		var len = projectEntries.length;
		for (var i = 0; i < len; i++) {
			projectIdValue = XmlUtil.getNodeValueStr(projectEntries[i], "id");
			if(projectIdValue == projectId) {
				return XmlUtil.getNodeValueStr(projectEntries[i], "client");
			}
		}
	},
 
	get_time_entry_prop_value: function(timeEntryXml, fetchEntity) {
		time_entry_node = XmlUtil.extractEntities(timeEntryXml, "day_entry")
		if (time_entry_node.length > 0) 
			return XmlUtil.getNodeValueStr(time_entry_node[0], fetchEntity);
	},	
}

harvestWidget = new HarvestWidget(harvestBundle, harvestinline);

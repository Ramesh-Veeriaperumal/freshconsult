var WorkflowMaxWidget = Class.create();
WorkflowMaxWidget.prototype = {
	WORKFLOW_MAX_FORM:new Template('<form id="workflow-max-timeentry-form"><div class="field first"><label>Staff</label><select name="staff-id" id="workflow-max-timeentry-staff" onchange="workflowMaxWidget.staffChanged(this.options[this.selectedIndex].value)" disabled class="full hide"></select> <div class="loading-fb" id="workflow-max-staff-spinner"></div></div><div class="field-35"><label>Client - Job</label><select class="full hide" name="job-id" id="workflow-max-timeentry-jobs" onchange="workflowMaxWidget.jobChanged(this.options[this.selectedIndex].value)" disabled></select> <div class="loading-fb" id="workflow-max-jobs-spinner"></div></div><div class="field last"><label>Task</label><select class="full hide" disabled name="task-id" id="workflow-max-timeentry-tasks"></select> <div class="loading-fb" id="workflow-max-tasks-spinner" ></div></div><div class="field"><label id="workflow-max-timeentry-notes-label">Notes</label><textarea disabled name="notes" id="workflow-max-timeentry-notes" wrap="virtual">'+workflowMaxBundle.workflowMaxNote.escapeHTML()+'</textarea></div><div class="field"><label id="workflow-max-timeentry-hours-label">Hours</label><input type="text" disabled name="hours" id="workflow-max-timeentry-hours"></div><input type="submit" disabled id="workflow-max-timeentry-submit" value="Submit" onclick="workflowMaxWidget.logTimeEntry($(\'workflow-max-timeentry-form\'));return false;"></form>'),
	CREATE_TIMEENTRY_REQ:new Template('<Timesheet><Job>#{job_id}</Job><Task>#{task_id}</Task><Staff>#{staff_id}</Staff><Date>#{date}</Date><Minutes>#{hours}</Minutes><Note><![CDATA[#{notes}]]></Note></Timesheet>'),
	UPDATE_TIMEENTRY_REQ:new Template('<Timesheet><ID>#{time_entry_id}</ID><Job>#{job_id}</Job><Task>#{task_id}</Task><Staff>#{staff_id}</Staff><Date>#{date}</Date><Minutes>#{hours}</Minutes><Note><![CDATA[#{notes}]]></Note></Timesheet>'),
	UPDATE_TIMEENTRY_ONLY_HOURS_REQ:new Template('<Timesheet><ID>#{time_entry_id}</ID><Minutes>#{hours}</Minutes></Timesheet>'),

	initialize:function(workflowMaxBundle, loadInline){
		widgetInst = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.jobData = ""; init_reqs = []; this.executed_date = new Date();
		this.auth_keys = "?apiKey="+workflowMaxBundle.k+"&accountKey="+workflowMaxBundle.a
		init_reqs = [null, {
			accept_type: "application/xml",
			method: "get", 
			resource: "job.api/tasks"+this.auth_keys,
			on_success: widgetInst.loadJobList.bind(this),
			on_failure: function(evt){}
		}]
		if (workflowMaxBundle.remote_integratable_id)
			init_reqs[0] = {
				accept_type: "application/xml",
				method: "get", 
				resource: "time.api/get/"+workflowMaxBundle.remote_integratable_id+this.auth_keys,
				on_success: widgetInst.loadTimeEntry.bind(this),
				on_failure: function(evt){}
			}
		workflowMaxOptions = {
			application_id:workflowMaxBundle.application_id,
			integratable_type:"timesheet",
			anchor: "workflow_max_widget",
			app_name:"Workflow Max",
			domain: workflowMaxBundle.api_url,
			application_content: function() {
				return widgetInst.WORKFLOW_MAX_FORM.evaluate({});
			},
			application_resources: init_reqs
		};

		if (typeof(workflowMaxBundle) != 'undefined' && workflowMaxBundle.k) {
			workflowMaxOptions.username = workflowMaxBundle.k;
			workflowMaxOptions.password = "x";
			this.freshdeskWidget = new Freshdesk.Widget(workflowMaxOptions);
		} else {
			workflowMaxOptions.login_content = function() {
				return '<form onsubmit="workflowMaxWidget.login(this); return false;" class="form">' + '<label>Authentication Key</label><input type="password" id="username"/>' + '<input type="hidden" id="password" value="X"/>' + '<input type="submit" value="Login" id="submit">' + '</form>';
			};
			this.freshdeskWidget = new Freshdesk.Widget(workflowMaxOptions);
		};
		if(loadInline) this.convertToInlineWidget();
	},

	loadTimeEntry: function(resData) {
		if (resData && this.isRespSuccessful(resData.responseXML)) {
			this.timeEntryXml = resData.responseXML;
			this.resetTimeEntryForm();
		}
	},

	loadJobList:function(resData){
		this.jobData = resData.responseXML
		this.loadStaffList();
	},

	handleLoadJob:function(staff_id) {
		var searchTerm = this.timeEntryXml ? this.get_time_entry_prop_value(this.timeEntryXml, ["Job", "ID"]) : null
		filterBy = staff_id ? {"Staff,ID":staff_id} : null
		if(this.isRespSuccessful(this.jobData)) {
			selectedJobNode = UIUtil.constructDropDown(this.jobData, 'xml', "workflow-max-timeentry-jobs", "Job", "ID", [["Client", "Name"], " ", "-", " ", "Name"], filterBy, searchTerm||"", false);
			jQuery("#workflow-max-timeentry-jobs").html(jQuery("#workflow-max-timeentry-jobs option").sort(function (a, b) {
   				return a.text == b.text ? 0 : a.text < b.text ? -1 : 1
			}))
		}
		UIUtil.hideLoading('workflow-max','jobs','-timeentry');
		$("workflow-max-timeentry-jobs").enable();
		this.jobChanged($("workflow-max-timeentry-jobs").value);
	},

	loadStaffList:function(){
		searchTerm = this.timeEntryXml ? this.get_time_entry_prop_value(this.timeEntryXml, ["Staff", "ID"]) : workflowMaxBundle.agentEmail

		job_list = XmlUtil.extractEntities(this.jobData, "Job"); staffData=[];
		for(var i=0;i<job_list.length;i++) {
			job_node = job_list[i];
			job_id = XmlUtil.getNodeValue(job_node, "ID")
			staff_nodes = XmlUtil.extractEntities(job_node, "Staff");
			for(var k=0;k<staff_nodes.length;k++) {
				matched = false
				for(var j=0;j<staffData.length;j++)
					if (staffData[j]["ID"] == XmlUtil.getNodeValue(staff_nodes[k], "ID")) matched = true;
				if (!matched) staffData.push({
							"ID":XmlUtil.getNodeValue(staff_nodes[k], "ID"), 
							"Name":XmlUtil.getNodeValue(staff_nodes[k], "Name")
					});
			}
		}
		staffData = {"Staff": staffData}

		UIUtil.constructDropDown(staffData, 'hash', "workflow-max-timeentry-staff", "Staff", "ID", ["Name"], null, searchTerm||"", false);
		UIUtil.hideLoading('workflow-max','staff','-timeentry');
		$("workflow-max-timeentry-staff").enable();
		this.staffChanged($("workflow-max-timeentry-staff").value);
	},

	jobChanged:function(job_id) {
		selectedJobNode = this.get_job_node(this.jobData, job_id)
		this.loadTaskList(selectedJobNode);
	},

	staffChanged:function(staff_id) {
		this.handleLoadJob(staff_id);
	},

	loadTaskList:function(resData) {
		var searchTerm = null
		if (this.timeEntryXml) {
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, ["Task", "ID"])
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		}
		selectedTaskNode = UIUtil.constructDropDown(resData, 'xml', "workflow-max-timeentry-tasks", "Task", "ID", ["Name"], null, searchTerm||"", false);
		UIUtil.hideLoading('workflow-max','tasks','-timeentry');

		$("workflow-max-timeentry-tasks").enable();
		$("workflow-max-timeentry-hours").enable();
		$("workflow-max-timeentry-notes").enable();
		$("workflow-max-timeentry-submit").enable();

		jQuery(".workflow_max_timetracking_widget").removeClass('still_loading');
	},

	validateInput:function() {
		var hoursSpent = parseFloat($("workflow-max-timeentry-hours").value);
		if(isNaN(hoursSpent)){
			alert("Enter valid value for hours.");
			return false;
		}
		if(!$("workflow-max-timeentry-jobs").value){
			alert("Please select a job.");
			return false;
		}
		if(!$("workflow-max-timeentry-tasks").value){
			alert("Please select a task.");
			return false;
		}
		return true;
	},

	logTimeEntry:function() {
		if (workflowMaxBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(resultCallback) {
		if (workflowMaxWidget.validateInput()) {
			var body = this.CREATE_TIMEENTRY_REQ.evaluate({
				staff_id: $("workflow-max-timeentry-staff").value,
				job_id: $("workflow-max-timeentry-jobs").value,
				task_id: $("workflow-max-timeentry-tasks").value,
				notes: $("workflow-max-timeentry-notes").value,
				hours: Math.ceil($("workflow-max-timeentry-hours").value*60),
				date: this.executed_date.toString("yyyyMMdd")
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				resource: "time.api/add"+this.auth_keys,
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					this.add_workflow_max_resource_in_db();
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
			var responses = XmlUtil.extractEntities(resXml,"Response");
			if (responses.length > 0) {
				this.freshdeskWidget.remote_integratable_id = this.get_time_entry_prop_value(responses[0], "ID")
			}
		}
	},

	// This method is for reusing same widget again and again in multiple time sheet entry forms.  So this will resets all the states of this form. 
	resetIntegratedResourceIds: function(integrated_resource_id, remote_integratable_id, local_integratable_id, is_delete_request) {
		workflowMaxBundle.integrated_resource_id = integrated_resource_id
		workflowMaxBundle.remote_integratable_id = remote_integratable_id
		this.freshdeskWidget.local_integratable_id = local_integratable_id
		this.freshdeskWidget.remote_integratable_id = remote_integratable_id
		if (!is_delete_request)
	   		if (workflowMaxBundle.remote_integratable_id)
	   			this.retrieveTimeEntry();
	   		else
	   			this.resetTimeEntryForm();
	},

	retrieveTimeEntry:function(resultCallback){
		if (workflowMaxBundle.remote_integratable_id) {
			this.freshdeskWidget.request({
				accept_type: "application/xml",
				method: "get", 
				resource: "time.api/get/"+workflowMaxBundle.remote_integratable_id+this.auth_keys,
				on_success: this.loadTimeEntry.bind(this),
				on_failure: function(evt){}
			});
		}
	},

	resetTimeEntryForm: function(){
		if(this.timeEntryXml) {
			// Editing the existing entry. Select already associated entry in the drop-downs that are already loaded.
			time_entry_node = XmlUtil.extractEntities(this.timeEntryXml, "Response")
			if (time_entry_node.length > 0) {
				staff_id = this.get_time_entry_prop_value(time_entry_node[0], ["Staff", "ID"]);
				UIUtil.chooseDropdownEntry("workflow-max-timeentry-staff", staff_id);
				this.staffChanged(staff_id)

				job_id = this.get_time_entry_prop_value(time_entry_node[0], ["Job", "ID"]);
				task_id = this.get_time_entry_prop_value(time_entry_node[0], ["Task", "ID"]);
				UIUtil.chooseDropdownEntry("workflow-max-timeentry-jobs", job_id);
				UIUtil.chooseDropdownEntry("workflow-max-timeentry-tasks", task_id);
			}
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		} else {
			// Do nothing. As this the form is going to be used for creating new entry, let the staff, client, job and task drop down be selected with the last selected entry itself. 
		}
		$("workflow-max-timeentry-hours").value = "";
		$("workflow-max-timeentry-notes").value = workflowMaxBundle.workflowMaxNote.escapeHTML();
		$("workflow-max-timeentry-notes").focus();
	},

	isRespSuccessful:function(resXml){
		var resEntities = XmlUtil.extractEntities(resXml,"Response");
		if(resEntities.length>0){
			var statusStr = XmlUtil.getNodeValueStr(resEntities[0],"Status"); errorStr = "";
			if(statusStr && statusStr == "OK")
				return true;
			else {
				if(statusStr == "")
					errorStr = "Unknown error occurred.";
				else 
					errorStr = XmlUtil.getNodeValueStr(resEntities[0],"ErrorDescription");
				alert("WorkflowMax reports the below error: \n\n" + errorStr + "\n\nTry again after correcting the error or fixing the error manually.  If you can not do so, contact support.");
				return false;
			}
		}
	},

	updateTimeEntryUsingIds:function(remote_integratable_id, hours, resultCallback) {
		if (remote_integratable_id) {
			var body = this.UPDATE_TIMEENTRY_ONLY_HOURS_REQ.evaluate({
				time_entry_id: remote_integratable_id,
				hours: (hours*60)+""
			});
			this.freshdeskWidget.request({
				body: body,
				content_type: "application/xml",
				method: "post",
				resource: "time.api/update"+this.auth_keys,
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					if(resultCallback) resultCallback(evt);
				}.bind(this)
			});
		}
	},

	// Methods for external widgets use.
	updateTimeEntry:function(resultCallback){
		if (workflowMaxBundle.remote_integratable_id) {
			if (workflowMaxWidget.validateInput()) {
				var body = this.UPDATE_TIMEENTRY_REQ.evaluate({
					time_entry_id: workflowMaxBundle.remote_integratable_id,
					staff_id: $("workflow-max-timeentry-staff").value,
					job_id: $("workflow-max-timeentry-jobs").value,
					task_id: $("workflow-max-timeentry-tasks").value,
					notes: $("workflow-max-timeentry-notes").value,
					hours: Math.ceil($("workflow-max-timeentry-hours").value*60),
					date: this.executed_date.toString("yyyyMMdd")
					// start_time: this.format_time(this.executed_date, 0),
					// end_time: this.format_time(this.executed_date, $("workflow-max-timeentry-hours").value*60)
				});
				this.freshdeskWidget.request({
					body: body,
					content_type: "application/xml",
					method: "put",
					resource: "time.api/update"+this.auth_keys,
					on_success: function(evt){
						this.handleTimeEntrySuccess(evt);
						if(resultCallback) resultCallback(evt);
					}.bind(this)
				});
			}
		} else {
			alert('WorkflowMax widget is not loaded properly. Please try again.');
		}
	},

	deleteTimeEntryUsingIds:function(integrated_resource_id, remote_integratable_id, resultCallback){
		if (remote_integratable_id) {
			this.freshdeskWidget.request({
				content_type: "application/xml",
				method: "delete",
				resource: "time.api/delete/"+remote_integratable_id+this.auth_keys,
				on_success: function(evt){
					this.handleTimeEntrySuccess(evt);
					this.delete_workflow_max_resource_in_db(integrated_resource_id, resultCallback);
					if(resultCallback) resultCallback(evt);
				}.bind(this)
			});
		}
	},

	deleteTimeEntry:function(resultCallback){
		if (workflowMaxBundle.remote_integratable_id) {
			deleteTimeEntryUsingIds(workflowMaxBundle.remote_integratable_id, workflowMaxBundle.integrated_resource_id, resultCallback)
		} else {
			alert('WorkflowMax widget is not loaded properly. Please delete the entry manually.');
		}
	},

	convertToInlineWidget:function() {
		$("workflow-max-timeentry-hours-label").hide();
		$("workflow-max-timeentry-notes-label").hide();
		$("workflow-max-timeentry-hours").hide();
		$("workflow-max-timeentry-notes").hide();
		$("workflow-max-timeentry-submit").hide();
	},

	updateNotesAndTimeSpent:function(notes, timeSpent, billable, executed_date) {
		$("workflow-max-timeentry-hours").value = timeSpent;
		$("workflow-max-timeentry-notes").value = (notes+"\n"+workflowMaxBundle.workflowMaxNote).escapeHTML();
		this.executed_date = new Date(executed_date);
	},

	// This is method needs to be called by the external time entry code to map the remote and local integrated resorce ids.
	set_timesheet_entry_id:function(integratable_id) {
		if (!workflowMaxBundle.remote_integratable_id) {
			this.freshdeskWidget.local_integratable_id = integratable_id;
			this.add_workflow_max_resource_in_db();
		}
	},

	add_workflow_max_resource_in_db:function() {
		this.freshdeskWidget.create_integrated_resource(function(evt){
			resJ = evt.responseJSON
			if (resJ['status'] != 'error') {
				workflowMaxBundle.integrated_resource_id = resJ['integrations_integrated_resource']['id'];
				workflowMaxBundle.remote_integratable_id = resJ['integrations_integrated_resource']['remote_integratable_id'];
			} else {
				alter("WorkflowMax: Error while associating the remote resource id with local integrated resource id in db.");
			}
			if (result_callback) 
				result_callback(evt);
			this.result_callback = null;
		}.bind(this));
	},

	delete_workflow_max_resource_in_db:function(integrated_resource_id, resultCallback){
		if (integrated_resource_id) {
			this.freshdeskWidget.delete_integrated_resource(integrated_resource_id);
			workflowMaxBundle.integrated_resource_id = "";
			workflowMaxBundle.remote_integratable_id = "";
		}
	},

	// private methods
	get_job_node: function(jobData, jobId){
		jobEntries = XmlUtil.extractEntities(jobData, "Job");
		for (var i = 0; i < jobEntries.length; i++) {
			jobIdValue = XmlUtil.getNodeValueStr(jobEntries[i], "ID");
			if(jobIdValue == jobId) {
				return jobEntries[i];
			}
		}
	},

	get_time_entry_prop_value: function(timeEntryXml, fetchEntity) {
		time_entry_node = XmlUtil.extractEntities(timeEntryXml, "Time")
		if (time_entry_node.length > 0) {
			time_entry_node = time_entry_node[0];
			return XmlUtil.getNodeValueStr(time_entry_node, fetchEntity);
		}
	},

	format_date: function(date) {
		// Workflow max is taking the date given here in timezone configured in workflow max.  So there is no need to use getUTC methods here.  In case the timezone configured in workflow max and the timezone of browser there will be some date discrepancy.
		m = (date.getMonth()+1)+""
		d = (date.getDate())+""
		return date.getFullYear()+""+(m.length > 1 ? m : "0"+m)+""+(d.length > 1 ? d : "0"+d)
	},
/*
	format_time: function(date, add_mins) {
		add_hours = Math.floor(add_mins/60)
		add_mins = add_mins%60
		h = (date.getHours()+add_hours)+""
		m = (date.getMinutes()+add_mins)+""
		return (h.length > 1 ? h : "0"+h)+":"+(m.length > 1 ? m : "0"+m)
	}*/
}

workflowMaxWidget = new WorkflowMaxWidget(workflowMaxBundle, workflow_maxinline);

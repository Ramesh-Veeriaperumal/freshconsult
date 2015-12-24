var WorkflowMaxWidget = Class.create();
WorkflowMaxWidget.prototype = {
	WORKFLOW_MAX_FORM:new Template('<form id="workflow-max-timeentry-form"><div class="field first"><label>Client</label><select name="client-id" id="workflow-max-timeentry-client" onchange="workflow_maxWidget.clientChanged(this.options[this.selectedIndex].value)" disabled class="full hide"></select> <div class="loading-fb" id="workflow-max-client-spinner"></div></div><div class="field first"><label>Staff</label><select name="staff-id" id="workflow-max-timeentry-staff" onchange="workflow_maxWidget.staffChanged(this.options[this.selectedIndex].value)" disabled class="full hide"></select> <div class="loading-fb" id="workflow-max-staff-spinner"></div></div><div class="field-35"><label>Job</label><select class="full hide" name="job-id" id="workflow-max-timeentry-jobs" onchange="workflow_maxWidget.jobChanged(this.options[this.selectedIndex].value)" disabled></select> <div class="loading-fb" id="workflow-max-jobs-spinner"></div></div><div class="field last"><label>Task</label><select class="full hide" disabled name="task-id" id="workflow-max-timeentry-tasks"></select> <div class="loading-fb" id="workflow-max-tasks-spinner" ></div></div><div class="field"><label id="workflow-max-timeentry-notes-label">Notes</label><textarea disabled name="notes" id="workflow-max-timeentry-notes" wrap="virtual">'+ jQuery('#workflow_max-note').html().escapeHTML() +'</textarea></div><div class="field"><label id="workflow-max-timeentry-hours-label">Hours</label><input type="text" disabled name="hours" id="workflow-max-timeentry-hours"></div><input type="submit" disabled id="workflow-max-timeentry-submit" value="Submit" onclick="workflow_maxWidget.logTimeEntry($(\'workflow-max-timeentry-form\'));return false;"></form>'),
	CREATE_TIMEENTRY_REQ:new Template('<Timesheet><Job>#{job_id}</Job><Task>#{task_id}</Task><Staff>#{staff_id}</Staff><Date>#{date}</Date><Minutes>#{hours}</Minutes><Note><![CDATA[#{notes}]]></Note></Timesheet>'),
	UPDATE_TIMEENTRY_REQ:new Template('<Timesheet><ID>#{time_entry_id}</ID><Job>#{job_id}</Job><Task>#{task_id}</Task><Staff>#{staff_id}</Staff><Date>#{date}</Date><Minutes>#{hours}</Minutes><Note><![CDATA[#{notes}]]></Note></Timesheet>'),
	UPDATE_TIMEENTRY_ONLY_HOURS_REQ:new Template('<Timesheet><ID>#{time_entry_id}</ID><Minutes>#{hours}</Minutes></Timesheet>'),
	CREATE_JOB:new Template('<div id="workflowmaxNewJob"><form id="workflow-max-jobentry-form" class="timesheet_form ui-form"><input type="hidden" name="selectedClient" value=#{client_id} id="selectedClient"><dl><dt class="jobName"><label>Job Name</label></dt><dd><input type="text" name="jobName" id="jobName"></dd><dt class="jobDesc"><label>Job Description</label></dt><dd><textarea name="jobDesc" id="jobDesc"></textarea></dd><dt></dt><dd pull-right><input type="button" id="workflow-max-jobentry-submit" value="Submit" onClick="workflow_maxWidget.logNewJob()";return false;" class="btn btn-mini btn-primary"> <input type="button" id="workflow-max-jobentry-cancel" value="Cancel" class="btn btn-mini" onClick="workflow_maxWidget.cancelNewJob()"; return false;"><dd></dl></form></div>'),
	CREATE_JOBENTRY_REQ:new Template('<Job><Name>#{job_name}</Name><Description>#{job_desc}</Description><StartDate>#{start_date}</StartDate> <DueDate>#{due_date}</DueDate><ClientID>#{client_id}</ClientID></Job>'),
	ASSIGN_STAFFENTRY_REQ:new Template('<Job><ID>#{job_id}</ID><add id="#{staff_id}"/></Job>'),
	ASSIGN_TASKENTRY_REQ:new Template('<Task><Job>#{job_id}</Job><TaskID>#{task_id}</TaskID><EstimatedMinutes>#{estimated_minutes}</EstimatedMinutes></Task>'),

	initialize:function(workflowMaxBundle, loadInline){
		workflow_maxWidget = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.jobData = ""; init_reqs = []; this.executed_date = new Date();
		this.bundle_data = workflowMaxBundle;
		workflowMaxBundle.workflowMaxNote = jQuery('#workflow_max-note').html();
		this.auth_keys = "?apiKey="+workflowMaxBundle.k+"&accountKey="+workflowMaxBundle.a
		
		init_reqs = [null, {
			accept_type: "application/xml",
			method: "get", 
			rest_url: "client.api/list"+this.auth_keys, 
			on_success: workflow_maxWidget.loadClientList.bind(this) 
		}]
		if (workflowMaxBundle.remote_integratable_id)
			init_reqs[0] = {
				accept_type: "application/xml",
				method: "get", 
				rest_url: "time.api/get/"+workflowMaxBundle.remote_integratable_id+this.auth_keys,
				on_success: workflow_maxWidget.loadTimeEntry.bind(this)
			}
		workflowMaxOptions = {
			widget_name:"workflow_max_widget",
			app_name:"Workflow Max",
			application_id:workflowMaxBundle.application_id,
			integratable_type:"timesheet",
			domain: workflowMaxBundle.api_url,
			application_html: function() {
				return workflow_maxWidget.WORKFLOW_MAX_FORM.evaluate({});
			},
			init_requests: init_reqs
		};

		if (typeof(workflowMaxBundle) != 'undefined' && workflowMaxBundle.k) {
			workflowMaxOptions.username = workflowMaxBundle.k;
			this.freshdeskWidget = new Freshdesk.Widget(workflowMaxOptions);
		} else {
			workflowMaxOptions.login_html = function() {
				return '<form onsubmit="workflow_maxWidget.login(this); return false;" class="form">' + '<label>Authentication Key</label><input type="password" id="username"/>' + '<input type="hidden" id="password" value="X"/>' + '<input type="submit" value="Login" id="submit">' + '</form>';
			};
			this.freshdeskWidget = new Freshdesk.Widget(workflowMaxOptions);
		};
		if(loadInline) this.convertToInlineWidget();
		this.delegateAddTimeClick();
	},

	delegateAddTimeClick: function(){
		jQuery(document).on('hidden.bs.modal', '#new_timeentry', function () {
			if(jQuery('#workflowmaxNewJob').length){
				workflow_maxWidget.cancelNewJob();
			}
		});
	},

	loadWorkflowmaxWidget: function(){
		this.freshdeskWidget.request({
			entity_name: "request",
			accept_type: "application/xml",
			method: "get", 
			rest_url: "client.api/list"+this.auth_keys,
			on_success: workflow_maxWidget.loadClientList.bind(this)
		})
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

	/*handleLoadJob:function(staff_id) {
		var searchTerm = this.timeEntryXml ? this.get_time_entry_prop_value(this.timeEntryXml, ["Job", "ID"]) : null
		filterBy = staff_id ? {"Staff,ID":staff_id} : null
		if(this.isRespSuccessful(this.jobData)) {
			selectedJobNode = UIUtil.constructDropDown(this.jobData, 'xml', "workflow-max-timeentry-jobs", "Job", "ID", [["Client", "Name"], " ", "-", " ", "Name"], filterBy, searchTerm||"", false);
			UIUtil.sortDropdown("workflow-max-timeentry-jobs");
		}
		UIUtil.hideLoading('workflow-max','jobs','-timeentry');
		$("workflow-max-timeentry-jobs").enable();
		this.jobChanged($("workflow-max-timeentry-jobs").value);
	}, */

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
		jQuery('#workflow-max-timeentry-tasks').hide();
		jQuery('#workflow-max-tasks-spinner').show();
		if(job_id == "newJob")
		{
			jQuery('#workflow_max-timeentry-enabled').attr('disabled','true')
			jQuery('.integration_container').hide();
			jQuery('#timeentry_apps_add').after(this.CREATE_JOB.evaluate({client_id: $("workflow-max-timeentry-client").value}));

		} else if (job_id == "..") {
			this.loadTaskEntry("");
		}
		else
		{
			//Taking tasklist with the job id
			jQuery('#workflowmaxNewJob').hide();
			this.freshdeskWidget.request({
			entity_name: "request",
			accept_type: "application/xml",
			method: "get", 
			rest_url: "job.api/get/"+job_id+this.auth_keys,
			on_success: workflow_maxWidget.loadTaskEntry.bind(this) })
		}
	},

	staffChanged:function(staff_id) {
		jQuery('#workflow_max-timeentry-enabled').removeAttr("disabled")
		jQuery('#workflow-max-timeentry-staff').addClass('header-spinner')

		this.freshdeskWidget.request({
		entity_name: "request",
		accept_type: "application/xml",
		method: "get", 
		rest_url: "job.api/staff/"+staff_id+this.auth_keys,
		on_success: workflow_maxWidget.loadJobEntry.bind(this) })

	},

	loadTaskList:function(resData) {
		var searchTerm = null
		if (this.timeEntryXml) {
			searchTerm = this.get_time_entry_prop_value(this.timeEntryXml, ["Task", "ID"])
			this.timeEntryXml = "" // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
		}
		selectedTaskNode = UIUtil.constructDropDown(resData, 'xml', "workflow-max-timeentry-tasks", "Task", "ID", ["Name"], null, searchTerm||"", false);
		UIUtil.hideLoading('workflow-max','tasks','-timeentry');
		this.enableWfmVariables();
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
		if($("workflow-max-timeentry-jobs").value == "noJob"){
			alert("Please select a job.");
			return false;
		}
		if($("workflow-max-timeentry-tasks").value == "noTask"){
			alert("No tasks available. Time entry will not be synced with Workflowmax");
			return false;
		}
		if(!$("workflow-max-timeentry-tasks").value){
			alert("Please select a task.");
			return false;
		}
		return true;
	},

	logTimeEntry:function(integratable_id) {
		if(integratable_id) 
			this.freshdeskWidget.local_integratable_id = integratable_id;
		if (workflowMaxBundle.remote_integratable_id) {
			this.updateTimeEntry();
		} else {
			this.createTimeEntry();
		}
	},

	createTimeEntry:function(integratable_id,resultCallback) {
		if(integratable_id) this.freshdeskWidget.local_integratable_id = integratable_id;
		//if(jQuery('.integration_container').css('display') != "none")
		{
			if (workflow_maxWidget.validateInput()) 
			{
				this.freshdeskWidget.request({
					entity_name: "request",
					accept_type: "application/xml",
					method: "get", 
					rest_url: "/job.api/tasks"+this.auth_keys,
					on_success: function(evt){
						isExists = this.validateResponse(evt);
						if(!isExists)
						{
							var body = this.ASSIGN_TASKENTRY_REQ.evaluate({
								job_id: $("workflow-max-timeentry-jobs").value,
								task_id: $("workflow-max-timeentry-tasks").value,
								estimated_minutes: "1400"
							});

							this.freshdeskWidget.request({
								body: body,
								content_type: "application/xml",
								method: "post",
								rest_url: "job.api/task"+this.auth_keys,

								on_success: function(evt){
									created_task_id = this.getTaskId(evt);
									task_id = created_task_id > 0 ? created_task_id : $("workflow-max-timeentry-tasks").value

									var body = this.CREATE_TIMEENTRY_REQ.evaluate({
										staff_id: $("workflow-max-timeentry-staff").value,
										job_id: $("workflow-max-timeentry-jobs").value,
										task_id: task_id,
										notes: $("workflow-max-timeentry-notes").value,
										hours: Math.ceil($("workflow-max-timeentry-hours").value*60),
										date: this.executed_date.toString("yyyyMMdd")
									});

									this.freshdeskWidget.request({
										body: body,
										content_type: "application/xml",
										method: "post",
										rest_url: "time.api/add"+this.auth_keys,
										on_success: function(evt){
											this.handleTimeEntrySuccess(evt);
											this.add_workflow_max_resource_in_db();
											if (resultCallback) {

												this.result_callback = resultCallback;
												resultCallback(evt);
											}
										}.bind(this)
									});
								}.bind(this)
							}); //job.api/task - post
						}
						else
						{
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
								rest_url: "time.api/add"+this.auth_keys,
								on_success: function(evt){
								this.handleTimeEntrySuccess(evt);
								this.add_workflow_max_resource_in_db();
							if (resultCallback) {
								this.result_callback = resultCallback;
								resultCallback(evt);
								}
							}.bind(this)
							});
						} //else ifexists -true
					}.bind(this) //jobapi.task success
				}); //job.api req - Get
			} //if validateinput ends
			return false;
		} //if display none ends
},

	handleTimeEntrySuccess:function(resData) {
		resXml = resData.responseXML;
		if(!resXml) return;
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
	   		if (workflowMaxBundle.remote_integratable_id){
	   			jQuery('.workflow_max_timetracking_widget .app-logo input:checkbox').attr('checked',true);	
                jQuery('.workflow_max_timetracking_widget .integration_container').toggle(jQuery('.workflow_max_timetracking_widget .app-logo input:checkbox').prop('checked'));
	   			this.retrieveTimeEntry();
	   		}
	   		else{
	   			jQuery('.workflow_max_timetracking_widget .app-logo input:checkbox').attr('checked',false);	
                jQuery('.workflow_max_timetracking_widget .integration_container').toggle(jQuery('.workflow_max_timetracking_widget .app-logo input:checkbox').prop('checked'));
	   			this.resetTimeEntryForm();
	   		}
	},

	retrieveTimeEntry:function(resultCallback){
		if (workflowMaxBundle.remote_integratable_id) {
			this.freshdeskWidget.request({
				accept_type: "application/xml",
				method: "get", 
				rest_url: "time.api/get/"+workflowMaxBundle.remote_integratable_id+this.auth_keys,
				on_success: this.loadTimeEntry.bind(this)
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
				this.staffChanged(staff_id);
			}
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
			/*var body = this.UPDATE_TIMEENTRY_ONLY_HOURS_REQ.evaluate({
				time_entry_id: remote_integratable_id,
			});*/
			this.freshdeskWidget.request({
				content_type: "application/xml",
				rest_url: "time.api/get/" + remote_integratable_id + this.auth_keys,
				on_success: function(response){
					var resXml = response.responseXML;
					var body = this.UPDATE_TIMEENTRY_REQ.evaluate({
						time_entry_id: remote_integratable_id,
						staff_id: this.get_time_entry_prop_value(resXml, ['Staff', 'ID']),
						job_id: this.get_time_entry_prop_value(resXml, ['Job', 'ID']),
						task_id: this.get_time_entry_prop_value(resXml, ['Task', 'ID']),
						notes: this.get_time_entry_prop_value(resXml, 'Note'),
						hours: Math.ceil((hours*60))+"",
						date: Date.parse(this.get_time_entry_prop_value(resXml, 'Date')).toString('yyyyMMdd')
					});
					this.freshdeskWidget.request({
						body: body,
						content_type: "application/xml",
						method: "put",
						rest_url: "time.api/update"+this.auth_keys,
						on_success: function(evt){
							this.handleTimeEntrySuccess(evt);
							this.resetIntegratedResourceIds();
							if(resultCallback) resultCallback(evt);
						}.bind(this)
					});
				}.bind(this)
				});
		}
	},

	// Methods for external widgets use.
	updateTimeEntry:function(resultCallback){
		if (workflowMaxBundle.remote_integratable_id) {
			if (workflow_maxWidget.validateInput()) {
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
					rest_url: "time.api/update"+this.auth_keys,
					on_success: function(evt){
						this.handleTimeEntrySuccess(evt);
						this.resetIntegratedResourceIds();
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
				rest_url: "time.api/delete/"+remote_integratable_id+this.auth_keys,
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
		time_entry_node_value = XmlUtil.extractEntities(timeEntryXml, "Time")
		if (time_entry_node_value.length > 0) {
			return XmlUtil.getNodeValueStr(time_entry_node_value[0], fetchEntity);
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

	
	loadClientList:function(resData) {
		this.clientData = resData.responseXML
		this.loadClientDataList();
	},

	loadClientDataList:function() {
		searchTerm = this.timeEntryXml ? this.get_time_entry_prop_value(this.timeEntryXml, ["Contact","Email"]) : workflowMaxBundle.agentEmail
		client_list = XmlUtil.extractEntities(this.clientData, "Client"); 
		clientData=[];  //this will contain only the matching records
		clientData_all=[]; //This will list all clients

		for(var i=0;i<client_list.length;i++) 
		{
			client_node = client_list[i];
			client_id = XmlUtil.getNodeValue(client_node, "ID");
			client_name = XmlUtil.getNodeValue(client_node, "Name");
			contact_list = XmlUtil.extractEntities(client_node, "Contact");
			clientData_all.push({"ID":client_id,"Name":client_name});
			for(var k=0;k<contact_list.length;k++)
			{
				contact_node = contact_list[k]
				contact_email = XmlUtil.getNodeValue(contact_node, "Email");
				if (workflowMaxBundle.agentEmail == contact_email){
					clientData.push({"ID":client_id,"Name":client_name});
				}
			}
		}
	
		if(clientData.length){
			this.showClientDropDown({"Client": clientData }, searchTerm)
		}
		else if (clientData_all.length){
			this.showClientDropDown({"Client": clientData_all }, searchTerm)
		}
		else 
		{
			jQuery('#workflow_max-timeentry-enabled').attr('disabled','true')
			jQuery('.integration_container').hide()
			jQuery('.workflow_max_timetracking_widget').after('<div class="alert error">No Clients available in workflowmax.</div>')
			jQuery(".workflow_max_timetracking_widget").removeClass('still_loading');		
		}
			
	},

	showClientDropDown:function(clientData,searchTerm) {
		UIUtil.constructDropDown(clientData, 'hash', "workflow-max-timeentry-client", "Client", "ID", ["Name"], null, searchTerm||"", false);
		UIUtil.hideLoading('workflow-max','client','-timeentry');
		$("workflow-max-timeentry-client").enable();
		this.clientChanged($("workflow-max-timeentry-client").value);

	},

	clientChanged:function(client_id) {
		this.loadStaffDetails(client_id);
	},
	
	loadStaffDetails:function (client_id) {
		var searchTerm =  this.timeEntryXml ? this.get_time_entry_prop_value(this.timeEntryXml, ["Client", "ID"]) : client_id
		filterBy = client_id ? {"Client ID":client_id} : null
		
		//Taking Stafflist with the client id
		this.freshdeskWidget.request({
		entity_name: "request",
		accept_type: "application/xml",
		method: "get", 
		rest_url: "job.api/client/"+client_id+this.auth_keys,
		on_success: workflow_maxWidget.loadStaffEntry.bind(this) })
	},

	removeDuplicates: function (array){
	    var length = array.length;
	    var ArrayWithUniqueValues = [];
	    var objectCounter = {};
	    for (i = 0; i < length; i++) {
	        var currentMemboerOfArrayKey = JSON.stringify(array[i]);
	        var currentMemboerOfArrayValue = array[i];
	        if (objectCounter[currentMemboerOfArrayKey] === undefined){
	            ArrayWithUniqueValues.push(currentMemboerOfArrayValue);
	             objectCounter[currentMemboerOfArrayKey] = 1;
	        }else{
	            objectCounter[currentMemboerOfArrayKey]++;
	        }
	    }
	    return ArrayWithUniqueValues;
	},

	loadStaffEntry:function(resData)
	{
		this.staffData = resData.responseXML
		var searchTerm = null;
		staffData=[]

		staff_list = XmlUtil.extractEntities(this.staffData, "Staff"); staffData=[];

		if(staff_list.length)
		{
			for(var i=0;i<staff_list.length;i++) 
			{
				staff_node = staff_list[i];
				staff_id = XmlUtil.getNodeValue(staff_node, "ID");
				staff_name = XmlUtil.getNodeValue(staff_node, "Name");
				staffData.push({"ID":staff_id,"Name":staff_name});
			}

			//array = staffData;
			finalStaffData = this.removeDuplicates(staffData)
			staffData = {"Staff": finalStaffData}
			UIUtil.constructDropDown(staffData, 'hash', "workflow-max-timeentry-staff", "Staff", "ID",  ["Name"], null, searchTerm||"", false);
			UIUtil.sortDropdown("workflow-max-timeentry-staff");
			UIUtil.hideLoading('workflow-max','staff','-timeentry');
			$("workflow-max-timeentry-staff").enable();
			this.staffChanged($("workflow-max-timeentry-staff").value);
		}
		else {
			//listing all Staffs
			this.freshdeskWidget.request({
				entity_name: "request",
				accept_type: "application/xml",
				method: "get", 
				rest_url: "staff.api/list"+this.auth_keys,
				on_success: workflow_maxWidget.loadAllStaffData.bind(this) })
			}
	},

	loadAllStaffData:function(resData){
		this.staffsData = resData.responseXML
		var searchTerm = null;

		staff_list = XmlUtil.extractEntities(this.staffsData, "Staff"); staffsData=[];

		if(staff_list.length)
		{
			for(var i=0;i<staff_list.length;i++) 
			{
				staff_node = staff_list[i];
				staff_id = XmlUtil.getNodeValue(staff_node, "ID");
				staff_name = XmlUtil.getNodeValue(staff_node, "Name");
				//console.log ("staff_id " + staff_id + " - staff name " + staff_name);
				staffsData.push({"ID":staff_id,"Name":staff_name});
			}
			staffsData = {"Staff": staffsData}
			UIUtil.constructDropDown(staffsData, 'hash', "workflow-max-timeentry-staff", "Staff", "ID",  ["Name"], null, searchTerm||"", false);
			UIUtil.sortDropdown("workflow-max-timeentry-staff");
			UIUtil.hideLoading('workflow-max','staff','-timeentry');
			$("workflow-max-timeentry-staff").enable();
			this.staffChanged($("workflow-max-timeentry-staff").value);
		} else {

			jQuery('#workflow_max-timeentry-enabled').attr('disabled','true');
			jQuery('.integration_container').hide();
			jQuery('.workflow_max_timetracking_widget').after('<div class="alert error">No Staffs available in Workflowmax</div>')

		}

	},

	loadJobEntry: function(resData){
		jQuery('#workflow-max-timeentry-jobs').addClass('header-spinner')
		this.jobData = resData.responseXML
		var searchTerm = null;
		job_list = XmlUtil.extractEntities(this.jobData, "Job"); jobData=[];
		if(job_list.length)
		{   
		  if(this.timeEntryXml){
			for(var i=0;i<job_list.length;i++){
				job_node = job_list[i];
				job_id = XmlUtil.getNodeValue(job_node, "ID");
				selected_client_list = XmlUtil.extractEntities(job_node, "Client");
				selected_client_id = XmlUtil.getNodeValue(selected_client_list[0], "ID");
				if(job_id == this.get_time_entry_prop_value(time_entry_node[0], ["Job", "ID"])){
					client_id = selected_client_id;
					UIUtil.chooseDropdownEntry("workflow-max-timeentry-client", client_id);
					break;
				}
			}
		}

			for(var i=0;i<job_list.length;i++) 
			{
				job_node = job_list[i];
				selected_client_list = XmlUtil.extractEntities(job_node, "Client");
				selected_client_id = XmlUtil.getNodeValue(selected_client_list[0], "ID");

				job_id = XmlUtil.getNodeValue(job_node, "ID");		
				if(selected_client_id == $("workflow-max-timeentry-client").value)
				{
					job_id = XmlUtil.getNodeValue(job_node, "ID");
					job_name = XmlUtil.getNodeValue(job_node, "Name");
					jobData.push({"ID":job_id,"Name":job_name.escapeHTML()});
				}	
			}
		}
		
		jobData.push({"ID":"..","Name":"..."});
		jobData.push({"ID": "newJob", "Name":"Create a new Job"});
		jobData = {"Job": jobData}
		UIUtil.constructDropDown(jobData, 'hash', "workflow-max-timeentry-jobs", "Job", "ID",  ["Name"], null, searchTerm||"", false);
		//UIUtil.sortDropdown("workflow-max-timeentry-jobs");
		UIUtil.hideLoading('workflow-max','jobs','-timeentry');
		$("workflow-max-timeentry-jobs").enable();
        
        if(this.timeEntryXml){
		job_id = this.get_time_entry_prop_value(time_entry_node[0], ["Job", "ID"]);
	    UIUtil.chooseDropdownEntry("workflow-max-timeentry-jobs", job_id);
	   }
		this.jobChanged($("workflow-max-timeentry-jobs").value);
	},

	validateJobInput:function()
	{
		var jobName = $("jobName").value;
		if(!$("jobName").value || !$("jobDesc").value)
		{
			alert("Provide value for Job name and description");
			return false;
		}
		return true;
	},

	loadTaskEntry: function(resData)  {
		var searchTerm = null;
		taskData=[];
		if(resData == "" || resData == null)
		{
			taskData.push({"ID": "noTask", "Name":"No tasks available"});
			taskData = {"Task": taskData}
			this.loadTaskComboBox(taskData,searchTerm);
		}
		else 
		{
			this.taskDataList = resData.responseXML;
			tasks_list = XmlUtil.extractEntities(this.taskDataList, "Task"); 
			if(tasks_list.length)
			{
				taskData = this.constructTasks(tasks_list);
				this.loadTaskComboBox(taskData,searchTerm);
			}
			else
			{
				this.freshdeskWidget.request({
				entity_name: "request",
				accept_type: "application/xml",
				method: "get", 
				rest_url: "/task.api/list"+this.auth_keys,
				on_success: function(evt){
						this.allTasks = evt.responseXML;
						tasks_list = XmlUtil.extractEntities(this.allTasks, "Task"); 
						if(tasks_list.length)
						{
							taskData = this.constructTasks(tasks_list);
							this.loadTaskComboBox(taskData,searchTerm);
						}
						else this.loadTaskEntry("");
					}.bind(this)
				});

			}
			
		}	
	},

	constructTasks: function(task_list)
	{
		taskData=[];
		for(var i=0;i<task_list.length;i++) 
				{
					task_node = task_list[i];
					task_id = XmlUtil.getNodeValue(task_node, "ID");
					task_name = XmlUtil.getNodeValue(task_node, "Name");
					taskData.push({"ID":task_id,"Name":task_name});
				}

		taskData = {"Task": taskData}
		return taskData;

	},

	loadAllTasksData : function(resData) {
		this.tasksData = resData.responseXML;
		tasksData=[];
		tasks_list = XmlUtil.extractEntities(this.tasksData, "Task"); 

		if(tasks_list.length)
			{
				for(var i=0;i<tasks_list.length;i++) 
				{
					tasks_node = tasks_list[i];
					task_id = XmlUtil.getNodeValue(tasks_node, "ID");
					task_name = XmlUtil.getNodeValue(tasks_node, "Name");
					tasksData.push({"ID":task_id,"Name":task_name});
				}
				tasksData = {"Task": tasksData}
				this.loadTaskComboBox(tasksData,null);
			}
	},


	loadTaskComboBox :function(taskData,searchTerm) {
		$('workflow-max-tasks-spinner').hide();
		$('workflow-max-timeentry-tasks').show();
		UIUtil.constructDropDown(taskData, 'hash', "workflow-max-timeentry-tasks", "Task", "ID",  ["Name"], null, searchTerm||"", false);
		UIUtil.sortDropdown("workflow-max-timeentry-tasks");
		UIUtil.hideLoading('workflow-max','tasks','-timeentry');
		$("workflow-max-timeentry-tasks").enable();
		this.enableWfmVariables();

        if(this.timeEntryXml){
		task_id = this.get_time_entry_prop_value(time_entry_node[0], ["Task", "ID"]);
		UIUtil.chooseDropdownEntry("workflow-max-timeentry-tasks", task_id);
		this.timeEntryXml = "";  			 // Required drop downs already populated using this xml. reset this to empty, otherwise all other methods things still it needs to use this xml to load them.
        }
	},

	enableWfmVariables:function () {
		$("workflow-max-timeentry-hours").enable();
		$("workflow-max-timeentry-notes").enable();
		$("workflow-max-timeentry-submit").enable();
		jQuery(".workflow_max_timetracking_widget").removeClass('still_loading');
	},


	logNewJob:function(){
		var job_desc = $("jobDesc").value;

		if (workflow_maxWidget.validateJobInput()) { 
			jQuery("#workflow-max-jobentry-submit").attr("disabled","disabled");
			var body = this.CREATE_JOBENTRY_REQ.evaluate({
				client_id: $("selectedClient").value,
				job_name: $("jobName").value.escapeHTML(),
				job_desc: $("jobDesc").value.escapeHTML(),
				start_date: this.executed_date.toString("yyyyMMdd"),
				due_date: this.executed_date.toString("yyyyMMdd")
			});
			this.freshdeskWidget.request({
					body: body,
					content_type: "application/xml",
					method: "post",
					rest_url: "job.api/add"+this.auth_keys,
					on_success: function(evt){
						this.handleJobEntrySuccess(evt);
						return false;
					}.bind(this)
				});
		}
	},	

	cancelNewJob:function(){
		jQuery('#workflowmaxNewJob').remove();
  		jQuery('.integration_container').show();
  		jQuery("#jobsuccessdiv").remove();
  		jQuery('#workflow-max-timeentry-form').trigger("reset");
  		jQuery('#workflow_max-timeentry-enabled').removeAttr("disabled")
  		this.loadWorkflowmaxWidget();
	},

	handleJobEntrySuccess:function(resData) {
		resXml = resData.responseText;
		xmlDoc = jQuery.parseXML(resXml);
		var node_value = xmlDoc.getElementsByTagName('Job')[0].childNodes[0];
		var newly_created_id = node_value.textContent;
		var body = this.ASSIGN_STAFFENTRY_REQ.evaluate({
				job_id: newly_created_id,
				staff_id: $("workflow-max-timeentry-staff").value
			});
			this.freshdeskWidget.request({
					body: body,
					content_type: "application/xml",
					method: "put",
					rest_url: "job.api/assign"+this.auth_keys,

					on_success: function(evt){
						jQuery('.workflow_max_timetracking_widget').after('<div id="jobsuccessdiv" class="alert sucess">Job added successfully</div>');
						window.setTimeout(function() {
				  			workflow_maxWidget.cancelNewJob();
				         }, 2000);
						//this.staffChanged($("workflow-max-timeentry-staff").value);
					}.bind(this)
				});
	},

	validateResponse:function(evt)
	{
		this.jobs = evt.responseXML;
		job_list = XmlUtil.extractEntities(this.jobs, "Job"); 
		if(job_list.length)
		{
			for(var i=0;i<job_list.length;i++) 
			{
				job_node = job_list[i];
				job_id = XmlUtil.getNodeValue(job_node, "ID");
				if(job_id == $("workflow-max-timeentry-jobs").value)
				{
					task_list = XmlUtil.extractEntities(job_node, "Task");
						if(task_list.length)
						{
							for(var k=0; k<task_list.length; k++)
							{
								task_node = task_list[k];
								task_id = XmlUtil.getNodeValue(task_node, "ID");
								if(task_id == $("workflow-max-timeentry-tasks").value)
								{
									return true;
								}
							}
						}
					}		
				}
				return false;
			}

	},

	getTaskId:function(evt)
	{
		var task_id = 0;
		var resEntities = XmlUtil.extractEntities(evt.responseXML,"Response");
		task_id = XmlUtil.getNodeValueStr(resEntities[0],"ID");
		return task_id;
	},
	
}

new WorkflowMaxWidget(workflowMaxBundle, workflow_maxinline);

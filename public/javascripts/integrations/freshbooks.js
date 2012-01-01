var FreshbooksWidget = Class.create();
FreshbooksWidget.prototype = {
	FRESHBOOKS_FORM:new Template('<form id="freshbooks-timeentry-form" name="freshbooks-timeentry-form"><fieldset class="freshbooks"><span class="logo"></span><div class="field"><label>Staff</label><select class="full" name="staff-id" id="freshbooks-timeentry-staff" onchange="freshbooksWidget.staffChanged(this.options[this.selectedIndex].value)"></select></div><div class="field"><label>Client</label><select class="full" name="client-id" id="freshbooks-timeentry-clients" onchange="freshbooksWidget.clientChanged(this.options[this.selectedIndex].value)"></select></div><div class="field"><label>Project</label><select class="full" name="project-id" id="freshbooks-timeentry-projects" onchange="freshbooksWidget.projectChanged(this.options[this.selectedIndex].value)"></select></div><div class="field"><label>Task</label><select name="task-id" id="freshbooks-timeentry-tasks" class="full" onchange="freshbooksWidget.taskChanged(this.options[this.selectedIndex].value)"></select></div><textarea disabled name="notes" class="hide" id="freshbooks-timeentry-notes" wrap="virtual" >'+freshbooksBundle.freshbooksNote.escapeHTML()+'</textarea><input type="text" disabled name="hours" id="freshbooks-timeentry-hours" class="hide"></fieldset></form>'),
   STAFF_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="staff.list"></request>'),
	CLIENT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="client.list"> <per_page>250</per_page></request>'),
	PROJECT_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?><request method="project.list"> <per_page>2000</per_page></request>'),
	TASK_LIST_REQ:new Template('<?xml version="1.0" encoding="utf-8"?> <request method="task.list" > <project_id>#{project_id}</project_id> </request>'),
	CREATE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.create"> <time_entry> <project_id>#{project_id}</project_id> <task_id>#{task_id}</task_id> <hours>#{hours}</hours> <notes><![CDATA[#{notes}]]></notes> <staff_id>#{staff_id}</staff_id> </time_entry></request>'),
	UPDATE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.update"> <time_entry> <time_entry_id>#{time_entry_id}</time_entry_id> <hours>#{hours}</hours> <notes><![CDATA[#{notes}]]></notes> </time_entry></request>'),
	DELETE_TIMEENTRY_REQ:new Template('<?xml version="1.0" encoding="ISO-8859-1"?><request method="time_entry.delete"> <time_entry_id>#{time_entry_id}</time_entry_id> </request>'),

	initialize:function(freshbooksBundle, loadInline){
		widgetInst = this; // Assigning to some variable so that it will be accessible inside custom_widget.
		this.projectData = ""; init_reqs = []
		if(!loadInline || freshbooksBundle.remote_integratable_id == '') {
			init_reqs = [{
				body: widgetInst.CLIENT_LIST_REQ.evaluate({}),
				content_type: "application/xml",
				method: "post", 
				on_success: widgetInst.loadClientList.bind(this)
			}, {
				body: widgetInst.STAFF_LIST_REQ.evaluate({}),
				content_type: "application/xml",
				method: "post", 
				on_success: widgetInst.loadStaffList.bind(this),
				on_failure: function(evt){}
			}, {
				body: widgetInst.PROJECT_LIST_REQ.evaluate({}),
				content_type: "application/xml",
				method: "post", 
				on_success: widgetInst.loadProjectList.bind(this),
				on_failure: function(evt){}
			}]
		}
		freshbooksOptions = {
			application_id:freshbooksBundle.application_id,
			integratable_type:"timesheet",
			anchor: "freshbooks_widget",
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

	loadStaffList:function(resData){
		this.loadFreshbooksEntries(resData, "freshbooks-timeentry-staff", "member", "staff_id", ["first_name", "last_name"], null, freshbooksBundle.agentEmail)
	},

	loadClientList:function(resData){
		selectedClientNode = this.loadFreshbooksEntries(resData, "freshbooks-timeentry-clients", "client", "client_id", ["first_name","last_name"], null, freshbooksBundle.reqEmail);
		client_id = XmlUtil.getNodeValueStr(selectedClientNode, "client_id");
		this.clientChanged(client_id);
	},

	loadProjectList:function(resData) {
		this.projectData=resData;
		this.handleLoadProject();
	},

	loadTaskList:function(resData) {
		this.taskData=resData;
		selectedTaskNode = this.loadFreshbooksEntries(this.taskData, "freshbooks-timeentry-tasks", "task", "task_id", ["name"], null, Cookie.get("fb_task_id")||"");
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
		console.log("Freshbooks handleLoadProject.");
		filterBy = {"client_id":$("freshbooks-timeentry-clients").value};
		selectedProjectNode = this.loadFreshbooksEntries(this.projectData, "freshbooks-timeentry-projects", "project", "project_id", ["name"], filterBy, Cookie.get("fb_project_id")||"");
		project_id = XmlUtil.getNodeValueStr(selectedProjectNode, "project_id");
		this.projectChanged(project_id);
	},

	projectChanged:function(project_id) {
		this.requestTaskList(project_id)
		Cookie.set("fb_project_id", project_id);
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
//		alert("task changed "+ task_id);
		Cookie.set("fb_task_id", task_id);
	},

	validateInput:function() {
		var hoursSpent = parseFloat($("freshbooks-timeentry-hours").value);
		if(isNaN(hoursSpent)){
			alert("Enter valid value for hours.");
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
					if (resultCallback) {
						this.result_callback = resultCallback;
						resultCallback(evt);
					}
					this.add_freshbooks_resource_in_db();
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
			}
//			resetTimeEntryForm();
		}
	},

	resetTimeEntryForm:function(){
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
				alert("An error occured: \n\n"+errorStr+"\nPlease contact support@freshdesk.com for further details.");
				return false;
			}
		}
		return true;
	},

	// Methods for external widgets use.
	updateTimeEntry:function(resultCallback){
		if (freshbooksBundle.remote_integratable_id) {
			if (freshbooksWidget.validateInput()) {
				var body = this.UPDATE_TIMEENTRY_REQ.evaluate({
					time_entry_id: freshbooksBundle.remote_integratable_id,
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
			alert('Freshbooks widget is not loaded properly. Please try again.');
		}
	},

	convertToInlineWidget:function() {
		if (freshbooksBundle.remote_integratable_id) {
			$("freshbooks-timeentry-form").hide();
		} else {
			$("freshbooks-timeentry-hours-label").hide();
			$("freshbooks-timeentry-notes-label").hide();
			$("freshbooks-timeentry-hours").hide();
			$("freshbooks-timeentry-notes").hide();
			$("freshbooks-timeentry-submit").hide();
		}
	},

	updateNotesAndTimeSpent:function(notes, timeSpent) {
		$("freshbooks-timeentry-hours").value = timeSpent;
		$("freshbooks-timeentry-notes").value = (notes+"\n"+freshbooksBundle.freshbooksNote).escapeHTML();
	},

	set_timesheet_entry_id:function(integratable_id) {
		if(integratable_id != null) this.freshdeskWidget.local_integratable_id = integratable_id;
		this.add_freshbooks_resource_in_db();
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
	}
}

freshbooksWidget = new FreshbooksWidget(freshbooksBundle);

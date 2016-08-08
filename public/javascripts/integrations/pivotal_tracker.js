var PivotalTrackerWidget = Class.create();
PivotalTrackerWidget.prototype = {
	PIVOTALTRACKER_FORM:new Template(	
		'<div class="row-fluid">' +
			'<div class="alert-text" id="error_display"></div>'+
			'<div class="form-horizontal">'+
				'<div class="control-group">'+
					'<label class="control-label">Project : </label>'+
					'<div class="controls">'+
						'<select class="select2 chrome-border-fix" id="pivotal_tracker_projects"> </select>'+
					'</div>'+
				'</div>'+
				'<div class="control-group">'+
					'<label class="control-label">Story Type : </label>'+
					'<div class="controls">'+
						'<select class="select2 chrome-border-fix" id="pivotal_story_type">'+
							'<option value=0>select story type</option>'+
							'<option value="feature">Feature</option>'+
							'<option value="bug">Bug</option>'+
							'<option value="chore">Chore</option>'+
							'<option value="release">Release</option>'+
						'</select>'+
					'</div>'+
				'</div>'+  
			'</div>'+
			'<div class="control-group bold">'+
				'<label class="control-label">Subject :<span class="required_star">*</span> </label>'+
				'<div class="controls">'+
					'<input  id="pivotal_tracker_subject"  size="20" type="text">'+
				'</div>'+
			'</div>'+
			'<div class="control-group bold">'+
				'<label class="control-label">Description : </label>'+
				'<div class="controls">'+
					'<textarea cols="30" rows="10" id="pivotal_tracker_description" class="span12" ></textarea>'+
				'</div>'+
			'</div>'+
		'</div>'
		),

	PIVOTALTRACKER_STORY:new Template(
		'<div title="pivotal_tracker_story_ticket">'+
		    '<div class="row-fluid" id="pivotaltracker_link">' +
				'</div>' +
   	  '</div>'
		),

	PIVOTALTRACKER_NO_STORY:new Template(
		'<div id="no_story">'+
			'<div class="row-fluid">' +
				'<label class="control-label">No story associated with this ticket.</label>'+
				'<a href="#" id="pivotaltracker_story_create" rel="freshdialog" class="add_requester_button" data-target="#pivotal_dialog"  data-destroy-on-close="false" data-width="610px" title="Create Story" data-submit-label="Create" data-close-label="Cancel" data-submit-loading="Creating story..." onclick="pivotalTrackerWidget.loadProjects();">Create story</a>'+
			'</div>'+
		'</div>'
		),

	PIVOTALTRACKER_NO_PROJECT:new Template(
		'<div id="no_story">'+
			'<div class="row-fluid">' +
				'<label class="control-label">No Project associated with this account.</label>'+
			'</div>'+
		'</div>'
		),

initialize : function(pivotal_bundle){
	var pivotalTrackerWidget = this;
	var get_story = [];
	var init_reqs = []; 
	this.projectsLoaded = false;
	this.btn = true;
	if (pivotal_bundle.remote_integratable_id) {
		get_story = pivotal_bundle.remote_integratable_id.split(",");
		this.requestCount = get_story.length;
		this.responseCount = 0;
		jQuery.each(get_story,function(i,val) {
			init_reqs.push({
				rest_url : "services/v5/projects/"+val,
				method: "get",
				content_type: "application/json",
				on_success: pivotalTrackerWidget.load_story.bind(pivotalTrackerWidget),
				on_failure: pivotalTrackerWidget.handlefailure
			});
		});
	}
	else {
		init_reqs=jQuery('#pivotal_tracker .content #story_content').html(pivotalTrackerWidget.PIVOTALTRACKER_NO_STORY.evaluate({}));
		jQuery("#pivotal_tracker_loading").remove();
	}
	this.stories = [];
	var failureHandler = function(evt){
		resJ = evt.responseJSON;
		if (resJ["code"] == "unauthorized_operation" || resJ["code"] == "unfound_resource")
		{
			pivotalTrackerWidget.handle_project_failure();
			pivotalTrackerWidget.responseCount += 1 ;
			if (pivotalTrackerWidget.responseCount == pivotalTrackerWidget.requestCount)
			{
				pivotalTrackerWidget.construct_story();
			}
		}
		else if (resJ["code"] == "invalid_authentication")
		{
			if(jQuery("#pivotal_dialog .modal-body")) {
				jQuery("#pivotal_dialog button[data-dismiss='modal']").click();
			}
			return alert("Invalid authentication credentials for Pivotal Tracker");
		}
		else
		{
			error_msg = resJ["error"];
			alert("Pivotal Tracker reported the following error: " + error_msg)
		}
	}
	this.freshdeskWidget = new Freshdesk.Widget({
		app_name: "pivotal_tracker",
		integratable_type:"issue-tracking",
		application_id: pivotal_bundle.application_id,
		use_server_password: true,
		auth_type: 'NoAuth',
		domain : "www.pivotaltracker.com" ,
		ssl_enabled: "true",
		init_requests: init_reqs
	});
	this.freshdeskWidget.resource_failure=failureHandler.bind(this.freshdeskWidget);
},

handle_project_failure: function() {
	var resource = pivotal_bundle.resource_id.split(",");
	this.freshdeskWidget.delete_integrated_resource(resource[this.responseCount]);
	this.btn = false;
	jQuery("#pivotal_tracker_loading").remove();
},

handlefailure: function() {
	if(jQuery("#pivotal_dialog .modal-body")) {
		jQuery("#pivotal_dialog button[data-dismiss='modal']").click();
	}
	return alert("Unknown server error. Please contact support@freshdesk.com.");
},

loadProjects: function() {
	if (this.projectsLoaded) {
		// jQuery("#pivotal_dialog .modal-body").html("<div class='sloading'> </div>");
		this.populate_loaded_project();
	}
	else
	{
		this.freshdeskWidget.request({
			rest_url: "services/v5/projects",
			method: "get",
			on_success: pivotalTrackerWidget.populateProjects.bind(this),
			on_failure: pivotalTrackerWidget.handlefailure
		});
	}
},

populateProjects: function(evt) {
	var resJSON = evt.responseJSON;
	if (resJSON.length == 0)
	{
		return jQuery("#pivotal_dialog .modal-body").html(pivotalTrackerWidget.PIVOTALTRACKER_NO_PROJECT.evaluate({}));
	}
	var populate_desc = "Ticket ID - " + pivotal_bundle.ticketId + "\n\n" + "Requester Email - " + pivotal_bundle.reqEmail + "\n\n" + "Description - " +jQuery("#pivotal_tracker #tkt_desc_pt").text();
	jQuery("#pivotal_dialog .modal-body").html("<div class='sloading'> </div>");
	jQuery("#pivotal_dialog .modal-body").html(pivotalTrackerWidget.PIVOTALTRACKER_FORM.evaluate({}));
	jQuery('#pivotal_tracker_subject').val(pivotal_bundle.ticketSubject);
	jQuery('#pivotal_tracker_description').val(populate_desc);
	var selectoptions = '<option value="0"> Select a project </option>';
	resJSON.each(function(project){
		selectoptions +='<option value="' + project["id"] + '">' + project["name"] + '</option>';
	});
	jQuery("#pivotal_tracker_projects").html(selectoptions);
	this.projectsLoaded=true;
},		

populate_loaded_project: function(){
	jQuery('#pivotal_dialog-submit').text( "Create" );
	jQuery('#pivotal_dialog-submit').attr("disabled", false);
	jQuery('#pivotal_tracker_projects').val(0).change();
	jQuery('#pivotal_story_type').val(0).change();
	var populate_desc = "Ticket ID - " + pivotal_bundle.ticketId + "\n\n" + "Requester Email - " + pivotal_bundle.reqEmail + "\n\n" + "Description - " +jQuery("#pivotal_tracker #tkt_desc_pt").text();
	jQuery('#pivotal_tracker_subject').val(pivotal_bundle.ticketSubject);
	jQuery('#pivotal_tracker_description').val(populate_desc);
	},

	load_story: function(evt) {
		storyJSON = evt.responseJSON;
		this.stories.push(storyJSON);
		this.responseCount = this.responseCount + 1;
		if (this.responseCount == this.requestCount)
		{
			pivotalTrackerWidget.construct_story();
		}
	},

	construct_story: function() {
		if (this.stories.length == 0)
		{
			jQuery('#pivotal_tracker .content #story_content').html(pivotalTrackerWidget.PIVOTALTRACKER_NO_STORY.evaluate({}));
		}
		else
		{
			jQuery('#pivotal_tracker .content #story_content').html(pivotalTrackerWidget.PIVOTALTRACKER_STORY.evaluate({}));
			var a_tag="<label>Associated Stories</label><ul class='disc'>";
			jQuery.each(this.stories,function(i,val) {
				a_tag = a_tag + "<li><a id='pv_story_" + val["id"] +"' href="+val["url"]+" target=_blank"+">"+val["name"]+
				"<br/>"+ "<label class='muted'>"+"#"+val["id"]+" - "+val["current_state"]+"</label>"+"</a></li>"
			});
			a_tag=a_tag + "</ul>"
			jQuery('#pivotal_tracker .content #story_content').html(a_tag);
		}
		if (this.btn) {																					
			jQuery('#pivotal_tracker .content #btn_content').html("<a href='#' id='add_story' rel='freshdialog' class='add_requester_button' data-target='#pivotal_dialog' data-width='610px' title='Create Story' data-destroy-on-close='false' data-submit-label='Create' data-close-label='Cancel' data-submit-loading='Creating story...' id='pivotaltracker_story_create' onclick='pivotalTrackerWidget.loadProjects();'>Create story</a>");
			this.btn = false;
			jQuery("#pivotal_tracker_loading").remove();
		}
	},

	createstory: function() {
		var projectId = jQuery("#pivotal_tracker_projects").val()
		if (projectId == 0) {
			return jQuery("#error_display").text( "Please select a project!" ).show().fadeOut(2000);
		}
		if (jQuery("#pivotal_story_type").val() == 0) {
			return jQuery("#error_display").text( "Please select the story type!" ).show().fadeOut(2000);
		}
		if (jQuery("#pivotal_tracker_subject").val().length < 1) {
			return jQuery("#error_display").text( "Subject cannot be empty" ).show().fadeOut(2000);
		}
		jQuery('#pivotal_dialog-submit').text( "Creating Story..." );
		jQuery('#pivotal_dialog-submit').attr("disabled", true);
		var story_data = JSON.stringify({
			name: jQuery("#pivotal_tracker_subject").val(),
			story_type: jQuery("#pivotal_story_type").val(),
			description: jQuery("#pivotal_tracker_description").val()
		})
		this.freshdeskWidget.request({
			rest_url: "services/v5/projects/" + projectId + "/stories",
			method: "post",
			dataType : "json",	
			content_type : "application/json",
			body : story_data,
			on_success: pivotalTrackerWidget.updateconfig.bind(this),
			on_failure: pivotalTrackerWidget.handlefailure
		});
	},

	reload_story_content: function(story_json) {
		this.stories.push(story_json);
		pivotalTrackerWidget.construct_story();
	},


	create_webhooks: function(project_id) {
		var project_ids = pivotal_bundle.webhooks_application_ids.split(",");
		var url_data = window.location.origin+"/integrations/pivotal_tracker/pivotal_updates";
		var post_data = JSON.stringify({
			"webhook_version" : "v5",
			"webhook_url" :  url_data
		});
		if(jQuery.inArray(project_id,project_ids) == -1 && pivotal_bundle.get_pivotal_updates == "1") {
			this.freshdeskWidget.request({
				rest_url: "services/v5/projects/" + project_id + "/webhooks",
				method: "post",
				dataType : "json",	
				content_type : "application/json",
				body : post_data,
				on_success: pivotalTrackerWidget.update_bundle.bind(this),
				on_failure: pivotalTrackerWidget.handlefailure
			});
		}
	},

	update_bundle: function(evt) {
		var webhooks_resp = evt.responseJSON;
		if (pivotal_bundle.webhooks_application_ids.length > 1) {
			pivotal_bundle.webhooks_application_ids += ","+webhooks_resp["project_id"];
		}
		else
		{
			pivotal_bundle.webhooks_application_ids = webhooks_resp["project_id"];
		}
	},

	updateconfig: function(evt) {
		var project_id = jQuery("#pivotal_tracker_projects").val();
		var ticket_id = pivotal_bundle.ticketId
		var pivotalTrackerWidget = this;
		var respJSON = evt.responseJSON;
		var config_url = "/integrations/pivotal_tracker/update_config?project_id="+respJSON["project_id"]+"&story_id="+respJSON["id"]+
		"&application_id="+pivotal_bundle.application_id+"&ticket_id="+pivotal_bundle.ticketId+"&story_name="+respJSON["name"]+
		"&story_url="+respJSON["url"]+"&project_name="+jQuery("#pivotal_tracker_projects option:selected").text()+"&story_type="+respJSON["story_type"];
		pivotalTrackerWidget.create_webhooks(project_id);
		jQuery.ajax({
			url: config_url,
			type: "POST",
			contentType : "application/json",
			success: function() {
				jQuery("#pivotal_dialog button[data-dismiss='modal']").click();
				pivotalTrackerWidget.reload_story_content(respJSON);
				show_growl_flash("Story added successfully");
				jQuery("#pv_story_"+ respJSON["id"]).effect("highlight", 3000);
			},
			error: function() { pivotalTrackerWidget.handlefailure }
		});
	}
}	

pivotalTrackerWidget = new PivotalTrackerWidget(pivotal_bundle);

jQuery(".ticket_details #pivotal_dialog-submit").off("click");
jQuery(".ticket_details").on("click" , "#pivotal_dialog-submit", function(eventObj) { 
	pivotalTrackerWidget.createstory();
});


var SurveyMonkey = Class.create(), sm;
var load_survey_list_req,
	sm_options = {},
	previous = "";

SurveyMonkey.prototype = { 
	ROW_TEMPLATE: new Template('<div>'+ '<div class="m-survey-row">'+
								"<div class = 'm-survey-remove'><div class = 'add-remove-optn remove'>&#8722;</div></div>"+
								"<div class = 'survey-monkey-content'>"+
								"<div class = 'inner-row'>"+
								"	<p> For tickets belonging to group </p>"+
								'	<select id="" class="group_list required select2">'+
								"	</select>"+
								"</div>"+
								"<div class = 'inner-row'>"+
								"	<div>"+
								"		<p> Use this survey </p>"+
								'		<div class="survey-list-wrapper sloading loading-small loading-left">'+
								'			<select id="" class="survey_list select2 required">'+
								'			</select>'+
								'		</div>'+
								'	</div>'+
								'	<div class="collector-container">'+
								'			<p> Survey Collector '+
								'			</p>'+
								'			<div class="hide collector-list-wrapper">'+
								'				<a href="#load_survey_link" rel="freshdialog" rel="freshdialog" data-group="survey-monkey" title="Preview" class="preview-link" data-template-footer=""> preview </a>'+
								'				<select id="" class="collector_list select2 required">'+
								'				</select>'+
								'			</div>'+
								'	</div>'+
								'</div>'+
							'</div>'+
							'<input type="hidden" class="survey_id hide" value="" />'+
							'<input type="hidden" class="collector_id hide"  value="" />'+
							'<input type="hidden" class="group_id hide" value="" />'+
							'<input type="hidden" class="survey_link hide" value="" />'+
							'</div>'+
							'</div>'),
	initialize: function() {
		sm = this;
		sm_options.app_name = "SurveyMonkey"
		sm_options.domain = "api.surveymonkey.net"
		
		sm_options.auth_type = "OAuth";
		sm_options.header_auth = true;
		sm_options.use_server_password = true;
		sm_options.useBearer = true;
		sm_options.url_auth = true;
		sm_options.url_token_key = 'api_key'
		sm_options.password = 'smonkey_secret';
		sm_options.ssl_enabled = true,
		
		sm_options.use_placeholders = true;
		// call the options loading function
		sm.load_group_list();
		sm_options.init_requests = [
			(load_survey_list_req = {
				body: '{"fields": ["title", "survey_id"]}',
				method: 'post',
				rest_url: 'v2/surveys/get_survey_list',
				use_placeholders: true,
				on_success: function(resData) {
					sm.load_survey_list(resData);
				},
				on_failure: function() {
					alert("Error loading list of surveys. Please refresh the page and try again. Contact support of problem persists.");
				}
			})
		]

		jQuery('body').on('change.surveymonkey', '.survey_list', function() {
			// change the hidden group_id based on the values selected group
			var selected_survey_id = jQuery(this).val();
			jQuery(this).find("option[selected=selected]").removeAttr("selected");

			if(selected_survey_id !=null || selected_survey_id !="") {
				jQuery(this).find("option[value='"+selected_survey_id+"']").attr("selected","selected");
			}

			jQuery(this).parents(".m-survey-row").find(".survey_id").val(selected_survey_id);
			jQuery(this).parents(".m-survey-row").find(".collector_id").val("");
			jQuery(this).parents(".m-survey-row").find(".survey_link").val("");
			jQuery(this).parents(".m-survey-row").find(".collector_list").select2("val", "");
			jQuery(this).parents(".m-survey-row").find(".collector_list").val("");
			var collector_container = jQuery(this).parents(".m-survey-row").find(".collector-container");
			var collector_list_wrapper = jQuery(this).parents(".m-survey-row").find(".collector-list-wrapper");

			jQuery(collector_container).addClass("sloading loading-small loading-left");
			jQuery(collector_list_wrapper).hide();
			jQuery(collector_container).find("a[rel='freshdialog']").hide();
			jQuery(collector_container).find("iframe").attr("src",""); // flush the preview link source since the survey is being changed.

			sm.fetch_survey_weblink_collectors(selected_survey_id, function(collectors) {
				ihtml = "<option value=\"\">- Select -</option>";
				collectors.each(function(collector) {
					ihtml = ihtml + "<option value=\"" + collector.id + "\" " +
									"data-collector-url=\"" + collector.url + "\">" + escapeHtml(collector.name) + "</option>";
				});
				jQuery(collector_list_wrapper).removeClass("sloading loading-small");
				jQuery(collector_container).removeClass("sloading loading-small loading-left");
				jQuery(collector_list_wrapper).show();
				// Populate the options for the collector_list
				jQuery(collector_container).find("select.collector_list").html(ihtml);
				return;
			}.bind(sm));
			sm.hide_preview_button_by_collector_value();
		});

		jQuery('body').on('click.surveymonkey', '.add-remove-optn.remove', function() {
			if(jQuery(".m-survey-row").length == 1) {
				alert("Atleast one group should be associated with a survey. In case if not needed then please disable the integration.");
			} else {
				curr_value = jQuery(this).parents(".m-survey-row").find("select.group_list").val();
				jQuery(".group_list").find("option[value="+curr_value+"]").removeAttr('disabled').removeClass("disabled");
				jQuery(this).parents(".m-survey-row").remove();
			}
			sm.show_or_hide_add_group_button();
		});

		jQuery('body').on('change.surveymonkey', '.collector_list', function() {
			var selected_collector_id = jQuery(this).val();
			jQuery(this).find("option[selected=selected]").removeAttr("selected");
			if(selected_collector_id !=null || selected_collector_id !="") {
				jQuery(this).find("option[value='"+selected_collector_id+"']").attr("selected","selected");
			}
			var survey_link = jQuery(this).find("option[value='"+selected_collector_id+"']").attr("data-collector-url");
			if (!survey_link) {
				survey_link = ""; // doing this because sometimes if the survey_link is null it is retaining the old state link name.
			}
			jQuery(this).parents(".m-survey-row").find(".collector_id").val(selected_collector_id);
			jQuery(this).parents(".m-survey-row").find(".survey_link").val(survey_link);
			sm.hide_preview_button_by_collector_value();
		});

		jQuery('body').on('change.surveymonkey', '.group_list', function() {
			sm.validate_group();
			var group_id = jQuery(this).val();
			var previous_group_val = jQuery(this).parents(".m-survey-row").find(".group_id").val();
			jQuery(".group_list").find("option[value="+previous_group_val+"]").removeAttr('disabled').removeClass("disabled");
			jQuery(this).parents(".m-survey-row").find(".group_id").val(group_id);
			jQuery(this).parents(".m-survey-row").find(".survey_id").attr('name', 'configs[groups]['+group_id+'][survey_id]').val("");
			jQuery(this).parents(".m-survey-row").find(".collector_id").attr('name', 'configs[groups]['+group_id+'][collector_id]').val("");
			jQuery(this).parents(".m-survey-row").find(".survey_link").attr('name', 'configs[groups]['+group_id+'][survey_link]').val("");

			jQuery(this).parents(".m-survey-row").find(".survey_list").select2("val","-1");
			jQuery(this).parents(".m-survey-row").find(".collector_list").select2("val","-1");
			jQuery(this).parents(".m-survey-row").find(".collector_list").trigger("change");
		});

		jQuery('body').on('click.surveymonkey', '.m-survey-add', function() {
			sm.add_a_group();
			sm.validate_group();
		});

		jQuery('body').on('click.surveymonkey', "a[rel='freshdialog']", function() {
			var survey_link = jQuery(this).parents(".m-survey-row").find(".survey_link").val(); // need to verify if this parent selection is correct.
			var group_id = jQuery(this).parents(".m-survey-row").find(".group_id").val(); // need to verify if this parent selection is correct.
			jQuery("#load_survey_link").find("iframe").attr("src", survey_link).load().show();
		});

		this.sm_options = sm_options;
		this.fd = new Freshdesk.Widget(this.sm_options);
		sm.load_collector_list();
		sm.show_or_hide_add_group_button();
		sm.hide_preview_button_by_collector_value();
	},

	load_group_list: function() {
		var ghtml = "";
		jQuery('.all_groups_base_reference option').each(function(i, obj) {
			ghtml = ghtml + "<option value='"+jQuery(obj).val()+"' >" + jQuery(obj).html() + "</option>";
		});
		jQuery("select.group_list").map(function() {
			var configured_group_id = jQuery(this).parents(".m-survey-row").find(".group_id").val();
			jQuery(this).html(ghtml);
			if(jQuery(this).prev().hasClass('select2-container')) {
				jQuery(this).select2("val",configured_group_id);
			}
			else {
				jQuery(this).val(configured_group_id);
			}
		});
		sm.validate_group();
	},

	load_survey_list: function(resData) {
		data = resData.responseJSON.data;
		if (!data || data.length==0) { /* No Survey */alert("No data!"); return;}
		sm.surveys = [];
		data.surveys.each(function(survey) {
			sm.surveys.push({name: survey.title, collectors: null, id: survey.survey_id})
		});
		/* This block populates the suvey options to the survey select boxes */
		if (sm.surveys.length) {
			has_only_one_survey = (sm.surveys.length==1);
			jQuery('.survey_id').map(function() {
				var ihtml = "<option value=\'\'>- Select -</option>";
				var configured_survey_id = jQuery(this).val();
				sm.surveys.each(function(s) {
					selected_attrib = ((s.id == configured_survey_id || has_only_one_survey) ? 'selected="selected" ' : '');
					ihtml += ("<option value=\"" + s.id + "\" " + selected_attrib + ">" + escapeHtml(s.name) + "</option>");
				});
				jQuery(this).parent().find(".survey-list-wrapper").removeClass("sloading loading-small loading-left");
				jQuery(this).parent().find("select.survey_list").html(ihtml);
				jQuery(this).parent().find("select.survey_list").select2("val", configured_survey_id);
				jQuery(this).parent().find("select.survey_list").val(configured_survey_id);
			});
		}
	},

	load_collector_list: function() {
		jQuery('.survey_id').map(function() {
			var configured_survey_id = jQuery(this).val();
			var configured_collector_id = jQuery(this).parent().find(".collector_id").val();
			var collector_container = jQuery(this).parent().find(".collector-container");
			var collector_list_wrapper = jQuery(this).parent().find(".collector-list-wrapper");
			if(!configured_survey_id || configured_survey_id == "") {
				jQuery(collector_container).removeClass("sloading loading-small loading-left");
			}
			jQuery(collector_container).find("a[rel='freshdialog']").hide();
			sm.fetch_survey_weblink_collectors(configured_survey_id, function(collectors) {
				var ihtml = "<option value=\"\">- Select -</option>";
				collectors.each(function(collector) {
					var selected_attrib = (configured_collector_id == collector.id ? 'selected="selected" ' : '');
					ihtml = ihtml + "<option value=\"" + collector.id + "\" " + selected_attrib +
									"data-collector-url=\"" + collector.url + "\">" + escapeHtml(collector.name) + "</option>";
				});
				jQuery(collector_container).find("select.collector_list").html(ihtml);
				jQuery(collector_list_wrapper).removeClass("sloading loading-small loading-left");
				jQuery(collector_list_wrapper).show();
				jQuery(collector_container).find("a[rel='freshdialog']").attr("style","display : inline;");
				//If the collector_list is of the class select2 then above selected won't work and it requires the below hack //
				jQuery(collector_container).find('select.collector_list').select2("val", configured_collector_id);
				jQuery(collector_container).removeClass("sloading loading-small loading-left");
				return;
			}.bind(sm));
			sm.validate_the_form();
		});
		sm.hide_preview_button_by_collector_value();
	},

	available_groups_for_map: function() {
		var all_fd_groups = [];
		var used_groups = [];
		jQuery('.all_groups_base_reference option').each(function(i, obj) {
			all_fd_groups.push(jQuery(obj).val());
		});
		jQuery('.group_list option[selected="selected"]').each(function(i, obj) {
			used_groups.push(jQuery(obj).val());
		});
		var available_groups = jQuery(all_fd_groups).not(used_groups).get();
		return available_groups;
	},

	option_name_by_val: function(opt_val){
		var text = jQuery(".all_groups_base_reference").find('option[value="'+opt_val+'"]').text();
		return text;
	},

	fetch_survey_weblink_collectors: function(survey_id, callback) {
		this.fd.request({
			rest_url: 'v2/surveys/get_collector_list',
			method: 'post',
			use_placeholders: true,
			body: '{"survey_id": "'+survey_id+'", "fields": ["id", "name", "type", "url"]}',
			on_success: function(res){
				var webLinks = [];
				res.responseJSON.data.collectors.each(function(collector){
					if (collector.type=='url') webLinks.push({name: escapeHtml(collector.name), url: collector.url, id: collector.collector_id});
				});
				if (webLinks.length) {
					callback(webLinks);
				} else {
					console.log("Probably there are no collectors for this survey");
					alert("Probably there are no collectors for this survey. Or it could also be a network connectivity failure please retry.")
				}
			}.bind(this),
			on_failure: function(res){
				alert("Error loading list of collectors. Please refresh the page and try again. Contact support of problem persists.");
			}
		});
	},

	add_a_group: function() {
		var row_html = sm.ROW_TEMPLATE.evaluate({});
		var temp_ele = jQuery(row_html).clone();

		var ghtml = "";
		jQuery('.all_groups_base_reference option').each(function(i, obj) {
			ghtml = ghtml + "<option value='"+jQuery(obj).val()+"' >" + jQuery(obj).html() + "</option>";
		});

		var shtml = "";
		jQuery("select.survey_list").first().find('option').each(function(i, obj) {
			shtml = shtml + "<option value='"+jQuery(obj).val()+"' >" + jQuery(obj).html() + "</option>";
		});

		jQuery(temp_ele).find(".group_list").html(ghtml);
		jQuery(temp_ele).find(".survey_list").html(shtml);
		jQuery(temp_ele).find(".survey-list-wrapper").removeClass("sloading loading-small loading-left");
		jQuery(".survey_for_groups").append(temp_ele.html());
		sm.validate_the_form();
		sm.show_or_hide_add_group_button();
	},

	hide_preview_button_by_collector_value: function() {
		// if the collector option is empty or --select -- then don't show the preview button.
		jQuery(".collector_list").map(function() {
			var collector_list_value = jQuery(this).val();
			if(collector_list_value == "" || collector_list_value == undefined || collector_list_value == null) {
				jQuery(this).parent().find("a[rel='freshdialog']").attr("style","display: none;");
			} else {
				jQuery(this).parent().find("a[rel='freshdialog']").attr("style","display: inline;");
			} 
		});
	},

	show_or_hide_add_group_button: function() {
		var total_groups_for_the_user = jQuery(".survey-fields-container .all_groups_base_reference option").length - 1; // -1 to Remove the first -- Select -- option.
		var total_groups_used_so_far = jQuery(".m-survey-row .group_id").length;
		if(total_groups_used_so_far < total_groups_for_the_user) {
			jQuery(".m-survey-add").removeClass("disabled");
			jQuery(".m-survey-add .add_group").removeClass("disabled");
		} else {
			jQuery(".m-survey-add").addClass("disabled");
			jQuery(".m-survey-add .add_group").addClass("disabled");
		}
	},

	validate_group: function() {
		jQuery("select.group_list").map( function() {
			if (jQuery(this).val() != "") {
				jQuery("select.group_list").not(this).find("option[value=" + jQuery(this).val() + "]").attr('disabled', 'disabled').addClass("disabled");
			} else {
				jQuery(this).val(null);
			}
		});
	},

	validate_the_form: function() {
			var count = 1;
			jQuery("select.survey_list").map(function() { 
				count++;
				jQuery(this).attr("name", "survey_box_"+count);
			});
			count = 1;
			jQuery("select.collector_list").map(function() {
				count++;
				jQuery(this).attr("name", "collector_box_"+count);
			});
			count = 1;
			jQuery("select.group_list").map(function() {
				count++;
				jQuery(this).attr("name", "group_box_"+count);
			});
	}

};
sm = new SurveyMonkey();


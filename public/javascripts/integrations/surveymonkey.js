
var SurveyMonkey = Class.create(), sm;
var load_survey_list_req;
var s2_options={minimumResultsForSearch: 10};
var sm_options = {};

SurveyMonkey.prototype = { 
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
		sm_options.init_requests = [
			(load_survey_list_req = {
				body: '{"fields": ["title", "survey_id"]}',
				method: 'post',
				rest_url: 'v2/surveys/get_survey_list',
				use_placeholders: true,
				on_success: function(resData){
					survey_id = Number(jQuery('#configured_survey_id').val());
					sm.ignore_change_event = true;
					sm.load_survey_list(resData, survey_id);
					sm.ignore_change_event = false;
					if(survey_id){
						collector_id = Number(jQuery('#configured_collector_id').val()) ;
						sm.update_collectors_list( collector_id )
					}
				},
				on_failure: function(){
					alert("Error loading list of surveys. Please refresh the page and try again. Contact support of problem persists.");
				}
			})
		]
		jQuery("#survey_list").on("change", function(){
			if(!sm.ignore_change_event) sm.update_collectors_list();
		});
		jQuery("#collector_list").on("change", function(){
			jQuery('#configured_collector_id').val(jQuery(this).find('option:selected').data('collector-id'));
		});
		this.sm_options = sm_options;
		this.fd = new Freshdesk.Widget(this.sm_options);
	},
	
	load_survey_list: function(resData, configured_survey_id){
		data = resData.responseJSON.data;
		if(!data || data.length==0){ /* No Survey */alert("No data!"); return;}
		sm.surveys = [];
		data.surveys.each(function(survey){
			sm.surveys.push({name: survey.title, collectors: null, id: survey.survey_id})
		});
		if(sm.surveys.length){
			ihtml = "<option value=\'\'>- Select -</option>";
			has_only_one_survey = (sm.surveys.length==1);
			sm.surveys.each(function(s){
				selected_attrib = ((s.id==configured_survey_id || has_only_one_survey)?'selected="selected" ':'');
				ihtml += ("<option value=\"" + s.id + "\" " + selected_attrib + ">" + s.name + "</option>");
				// Fetch collector
			});
			jQuery("#survey-list-wrapper").removeClass("sloading loading-small loading-left")
			jQuery("#survey_list").html(ihtml).trigger("change").prev().show();
		}
	},

	update_collectors_list: function(configured_collector_id){
		if(jQuery('#survey_list').val()==''){ jQuery('#collector-container').hide(); return; }
		survey_list = document.getElementById('survey_list');
		selected_survey_id = survey_list.options[survey_list.selectedIndex].value;
		jQuery('#configured_survey_id').val(selected_survey_id);
	
		sm.fetch_survey_weblink_collectors(selected_survey_id, function(collectors){
			jQuery("#collector-container").show();
			jQuery("#collector-list-wrapper").removeClass('sloading loading-small loading-left');
			jQuery('#s2id_collector_list').show();
		
			ihtml = "<option value=\"\">Select</option>";
			survey.collectors.each(function(collector){
				selected_attrib = (configured_collector_id==collector.id?'selected="selected" ':'')
				ihtml = ihtml + "<option value=\"" + collector.url + "\" " + selected_attrib +
								"data-collector-id=\"" + collector.id + "\">" + collector.name + "</option>";
			});
			jQuery("#collector_list").html(ihtml).trigger('change'); 
			return;
			
		}.bind(sm));
	},

	fetch_survey_weblink_collectors: function(survey_id, callback){		
		survey = this.get_survey_by_id(survey_id);	
		if(survey.collectors) return callback(survey.collectors);								
		jQuery("#collector-container").show();
		jQuery("#collector-list-wrapper").addClass('sloading loading-small loading-left');
		jQuery('#s2id_collector_list').hide();
		this.fd.request({
			rest_url: 'v2/surveys/get_collector_list',
			method: 'post',
			use_placeholders: true,
			body: '{"survey_id": "'+survey_id+'", "fields": ["id", "name", "type", "url"]}',
			on_success: function(res){
				var webLinks = [];
				res.responseJSON.data.collectors.each(function(collector){
					if(collector.type=='url') webLinks.push({name: collector.name, url: collector.url, id: collector.collector_id});
				});
				if(webLinks.length){
					survey = this.get_survey_by_id(survey_id);
					survey.collectors = webLinks;
					if(survey_id == Number(jQuery('#survey_list option:selected').val()))
						callback(survey.collectors);
				} else {
					ihtml = "<option value=\"\">Select</option>"; 
					jQuery("#collector_list").html(ihtml).trigger("change");
				}
			}.bind(this),
			on_failure: function(res){
				alert("Error loading list of collectors. Please refresh the page and try again. Contact support of problem persists.");
			}
		});
	},

	get_survey_by_id: function(survey_id){
		if(this.surveys){
			for(i=0; i<this.surveys.length; i++){
				if(this.surveys[i].id == survey_id) return this.surveys[i];
			}
		}
		return null;
	}

};


sm = new SurveyMonkey();

jQuery(document).ready(function(){
	jQuery("#survey_list, #collector_list").select2(s2_options);

});


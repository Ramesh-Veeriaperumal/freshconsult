
var Helpkit = Helpkit || {};
Helpkit.ScheduleUtil = Helpkit.ScheduleUtil || {};

Helpkit.ScheduleUtil = { 
	   	modifyScheduleDialog : function(title_editable) {
    		
             
            if(!title_editable){
    			var default_report_title = jQuery(".reports-menu li.active a").attr('data-original-title');
    			jQuery(".default_report_name").removeClass('hide').html(escapeHtml(default_report_title));
    			jQuery(".colon_seperator").removeClass('hide');
                jQuery("#filter_name_save").hide().val(default_report_title);

    			//Modify the title of dialog
    			jQuery("#report-dialog-save .modal-title").html(I18n.t('helpdesk_reports.saved_report.schedule_header'));
    		} else {
    			jQuery(".default_report_name").addClass('hide');
                jQuery(".colon_seperator").addClass('hide');
    			jQuery("#filter_name_save").show();
    			//Set the value of input field
	    		var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
	    		jQuery("#filter_name_save").val(current_title);
    		} 
    	},
	    getScheduleParams : function() {
	    	var _this = this;
	    	var config = {
                scheduled_task : {},
                schedule_configuration: {
                    config : {}
                }
            };
            if(is_schedule_off){
                config.enabled = false;
                return config;
            }

            if(is_scheduled_op){
                config.enabled = true;
                config.schedule_configuration.config.subject = jQuery(".schedule .subject").val();
                config.schedule_configuration.config.description = jQuery(".desc").val();
                var email_data = jQuery(".email").select2('data');
                if( email_data && email_data.length > 0) {
                    
                    config.schedule_configuration.config.emails = {};
                    var user_ids_in_email = []; 

                    jQuery.each(email_data,function(idx,opt) {
                        if(jQuery.inArray(opt.id,user_ids_in_email) == -1) {
                            user_ids_in_email.push(opt.id);
                        }
                        config.schedule_configuration.config.emails[opt.email] = opt.id;

                    }); 
                    config.schedule_configuration.config.email_source = email_data;
                }
                
                config.scheduled_task.frequency = jQuery(".frequency").val();
                if(_this.checkFrequency.isWeekly()) {
                    config.scheduled_task.day_of_frequency = jQuery("[name=day]:checked").val();
                }
                if(_this.checkFrequency.isMonthly()) {
                    config.scheduled_task.day_of_frequency = jQuery(".day_of_mnth").val();
                }

                //Time
                 if(_this.checkFrequency.isWeekly() || _this.checkFrequency.isMonthly()) {
                    var selected_time = parseInt(jQuery(".inner-time-picker .timer").val());
                    config.scheduled_task.minute_of_day = _this.convertToMinOfDay(selected_time);
                 } else {
                    var selected_time = parseInt(jQuery(".outer-time-picker .timer").val());
                    config.scheduled_task.minute_of_day = _this.convertToMinOfDay(selected_time);
                 }
            } else {
                config.enabled = false;
            }
	    	
	    	return config;
	    },
	    constructTimePicker : function() {
	    	
	    	var el = jQuery(".hours .timer");
	    	jQuery(el).empty();

            for(i = 4 ; i <= 23 ; i++) {
                el.append(jQuery('<option>', {
                    value: i,
                    text: i + ":00"
                }));
            }    

            //Set timezone
            jQuery(".tzone").html(current_user.time_zone);
	    },
        constructDayPicker : function(){
            var el = jQuery(".day_of_mnth");
            jQuery(el).empty();
            for(i = 1 ; i <=31 ; i++) {
                el.append(jQuery('<option>', {
                    value: i,
                    text: this.ordinal_suffix_of(i)
                }));
            }
            el.append(jQuery('<option>', {
                value: 31,
                text: 'Last Day'
            }));  
        },
        ordinal_suffix_of : function(i) {
            var j = i % 10,
                k = i % 100;
            if (j == 1 && k != 11) {
                return i + "st";
            }
            if (j == 2 && k != 12) {
                return i + "nd";
            }
            if (j == 3 && k != 13) {
                return i + "rd";
            }
            return i + "th";
        },
	    constructScheduleFields : function(hideSection,last_applied_saved_report_index,default_report_is_scheduled,default_index,filterChanged,data,enable) {
    		var _this = this;

            if(enable) {
                    jQuery('.disabled').addClass('hide');
                    jQuery('.schedule .title').removeClass('hide');

                    var hash;
                    if(last_applied_saved_report_index == -1 ) {
                        if(default_report_is_scheduled && !filterChanged) {
                             hash = data[default_index].report_filter.data_hash;
                        } 
                    } else {
                        hash = data[last_applied_saved_report_index].report_filter.data_hash;
                    }

                    //Email
                    var email = '<input type="hidden" class="email" style="width:100%" class="input-xlarge filter_item" />';
                    jQuery(".email_container").empty();
                    jQuery(".email_container").html(email);

                    //Desc
                    jQuery(".desc").removeAttr('edited');

                    if(hash && hash.schedule_config.enabled) {
                        var conf = _this.getRemoteFilterConfig(true,hash.schedule_config.schedule_configuration.config.email_source);
                        jQuery(".email").select2(conf);
                        var user_id = [];
                        if(hash.schedule_config != undefined) {
                            jQuery.each(hash.schedule_config.schedule_configuration.config.email_source,function(idx,source){
                                user_id.push(source.user_id);
                            });    
                        }
                        jQuery(".email").select2('val',user_id);
                    }else{
                        var initData = [];
                        initData.push({
                            email : current_user.mail,
                            id : current_user.id,
                            text : current_user.mail
                        });
                        var conf = _this.getRemoteFilterConfig(true,initData);
                        jQuery(".email").select2(conf);
                        jQuery(".email").select2('val',current_user.id);
                    }

                    //Timepicker
                    _this.constructTimePicker();
                    _this.constructDayPicker();

                    //Hide Runat initially
                    jQuery(".runat").css('display','none');

                    if(hash && hash.schedule_config.enabled) {
                        _this.populateScheduleFields(hash.schedule_config);
                        //put delete button in footer
                        var off_tmpl = _.template('<a href="#" data-submit="modal" class="btn pull-left" id="report-dialog-off-submit">Delete Schedule</a>');
                        jQuery(".modal-footer").prepend(off_tmpl);
                        _this.bindScheduleEvents(false);
                        not_scheduled  = false;
                    } else{
                        not_scheduled  = true;
                        _this.populateRunAt(); 
                        _this.populateDescription();
                        _this.populateSubject();
                        _this.bindScheduleEvents(true);
                    }

                    
            } else {
                 jQuery('.disabled').removeClass('hide');
                 jQuery('.schedule .title').addClass('hide');
            }
	    },
        populateRunAt : function(){
            var date_const = Helpkit.DateRange;
            var range;
            if(typeof HelpdeskReports != 'undefined') {
                range = HelpdeskReports.locals.presetRangesPeriod;
            } else {
                range = Helpkit.presetRangesPeriod;
            }   
             
            var freq_picker = jQuery('.frequency');
            var weekday_picker = jQuery('.weekly');
            var day_picker = jQuery('.monthly');

            if(range == date_const.TODAY ||
                 range == date_const.YESTERDAY ) {
                freq_picker.val('1');

            } else if(range == date_const.LAST_7 || 
                        range == date_const.THIS_WEEK || 
                            range == date_const.PREVIOUS_WEEK) {
                freq_picker.val('2');

            } else {
                freq_picker.val('3');
            }
            this.freqOnChange(false);
            
        },
	    populateDescription : function(){
    		 
    		var frequency = jQuery(".frequency").val(); 
    		var data = {
    			report_name : jQuery("#filter_name_save").val(),
    			schedule : jQuery(".frequency option[value='" + frequency + "']").text(),
                username : current_user.name
    		}
            jQuery(".desc").val(I18n.t('helpdesk_reports.saved_report.desc',data));
	    },
        populateSubject : function(){
             //populate default values for desc
            var subject_tmpl = _.template("<%= report_name %> - <%= schedule %>");
             
            var frequency = jQuery(".frequency").val(); 
            var data = {
                report_name : jQuery("#filter_name_save").val(),
                schedule : jQuery(".frequency option[value='" + frequency + "']").text()
            }
            jQuery(".subject").val(subject_tmpl({
                report_name : data.report_name,
                schedule : data.schedule
            }));
        },
	    populateScheduleFields : function(data) {

	    	var _this = this;
    		var subject = jQuery(".subject");
    		var desc = jQuery(".desc");
    		var timer = jQuery(".timer");
    		var frequency = jQuery(".frequency"); 
    		//var zone = jQuery(".zone");

    		subject.val(data.schedule_configuration
.config.subject);
    		desc.val(data.schedule_configuration
.config.description);
            var hour_24 = _this.minToHours(data.scheduled_task.minute_of_day);
    		frequency.val(data.scheduled_task.frequency);
            _this.constructTimePicker();
            timer.val(hour_24);
    		
    		//zone.val(data.clock_12_hour.zone);

            
    		if(_this.checkFrequency.isWeekly(data.scheduled_task.frequency)) {
                    jQuery("[name=day][value='"+ data.scheduled_task.day_of_frequency +"']").prop("checked",true);
	    	} 

	    	if(_this.checkFrequency.isMonthly(data.scheduled_task.frequency)) {
				    jQuery(".day_of_mnth").val(data.scheduled_task.day_of_frequency);
	    	}
            _this.freqOnChange(false);

	    },
	    bindScheduleEvents :function(bindFreq) {
	    	var _this = this;

	    	//Since dialog will be recreated everytime, flush events and re-attach
	    	jQuery(document).off(".schedule");

			jQuery(document).on("blur.schedule","#filter_name_save",function() {
                var truncate = _this.stripTags(jQuery("#filter_name_save").val());
                jQuery("#filter_name_save").val(truncate);

				var edited = jQuery(".desc").attr('edited');

				if(edited == undefined) {
					_this.populateDescription();
				}

                edited = jQuery(".subject").attr('edited');
                if(edited == undefined) {
                    _this.populateSubject();
                }
				//_this.showOverviewMessage();
			});

			//If users once types in desc , mark the attr and
			//no more auto updating on editing title
			jQuery(document).one("keyup.schedule",".desc",function() {
				jQuery(".desc").attr('edited',true);
			});
            jQuery(document).one("keyup.schedule",".subject",function() {
                jQuery(".desc").attr('edited',true);
            });

			jQuery(document).on("change.schedule",".frequency",function() {
                    _this.freqOnChange(true);
            });

			jQuery(document).on("change.schedule",".timer,.clocker,[name=day]",function(){
                    //_this.showOverviewMessage();
			});
	    },
        freqOnChange : function(updateFields){
            var _this = this;
            var val = jQuery(".frequency").val();
            if(_this.checkFrequency.isWeekly() || _this.checkFrequency.isMonthly()) {
                jQuery(".runat").show();
                jQuery(".inner-time-picker").removeClass('hide');
                jQuery(".outer-time-picker").addClass('hide');
                if(_this.checkFrequency.isWeekly()){
                    jQuery('.weekly').removeClass('hide');  
                }else{
                    jQuery('.weekly').addClass('hide');
                }
                
                if(_this.checkFrequency.isMonthly()){
                    jQuery('.monthly').removeClass('hide'); 
                }else{
                    jQuery('.monthly').addClass('hide');    
                }
                
            } else {
                    jQuery(".runat").hide();
                    jQuery(".inner-time-picker").addClass('hide');
                    jQuery(".outer-time-picker").removeClass('hide');
                    jQuery('.monthly,.weekly').addClass('hide');
            }

            if(updateFields && not_scheduled){
                var edited = jQuery(".desc").attr('edited');

                if(edited == undefined) {
                    _this.populateDescription();
                }
                edited = jQuery(".subject").attr('edited');
                if(edited == undefined) {
                    _this.populateSubject();
                }
            }
            //_this.showOverviewMessage();
        },
	    getRemoteFilterConfig : function(initFromSavedReportData,initData){
		     var _this = this;
		     var config = {
		        maximumSelectionSize: 10
		   	 };
		     config.ajax = {
		        url: "/search/autocomplete/requesters",
		        dataType: 'json',
		        delay: 250,
                cache : false,
		        data: function (term, page) {
		            return {
		                q: term, // search term
		            };
		        },
		        results: function (data, params) {
		                  var results = [];
		                  jQuery.each(data.results, function(index, item){
		                        results.push({
		                          id: item.id,
		                          text: item.details,
		                          email : item.email
		                        });
		                  });
		                  return {
		                    results: results 
		                  };
		        }
		   	  };
		      config.multiple = true ;
		      config.minimumInputLength = 2 ;
		      config.initSelection = function (element, callback) {
		            if(initFromSavedReportData){
		                callback(initData);
		            } 
		        };
		    return config;
    	},
    	isScheduled : function(last_applied_saved_report_index,default_report_is_scheduled,default_index,data) {
    		
    		var _this = this;
    		var result = {
    			is_scheduled : false,
    			tooltip_title : ""
    		};
    		var is_scheduled = false;
    		var hash;
    		if(last_applied_saved_report_index == -1) {
    			if(default_report_is_scheduled){
    				hash = data[default_index];
	    			var schedule_config = hash.report_filter.data_hash.schedule_config;
	    			if(schedule_config) {
	    				is_scheduled = schedule_config.enabled;
	    			}
    			}
    		} else{
    			hash = data[last_applied_saved_report_index];
    			var schedule_config = hash.report_filter.data_hash.schedule_config;
    			if(schedule_config) {
    				is_scheduled = schedule_config.enabled;
    			}
    		}
    		result.is_scheduled = is_scheduled;
    		if(is_scheduled) {
    			result.tooltip_title = _this.getTooltipMessage(hash.report_filter.data_hash.schedule_config);
    		}
    		return result;
    	},
        displayScheduleStatus : function(yes,message){
            var _this = this;
            if(yes){
                jQuery('.calendar').addClass('scheduled');
                _this.setTwipsyContent(message);
            }else{
                jQuery('.calendar').removeClass('scheduled');
                _this.setTwipsyContent(I18n.t('helpdesk_reports.saved_report.create_schedule'));
            }
            
        },
        getTooltipMessage : function(hash) {
            var _this = this;
            var trans = {
                scope : 'helpdesk_reports.saved_report'
            }
            if(_this.checkFrequency.isDaily(hash.scheduled_task.frequency)) {
                trans.period = "day";
            }  
            if(_this.checkFrequency.isWeekly(hash.scheduled_task.frequency)) {
                var weekday = hash.scheduled_task.day_of_frequency;
                trans.period = day_names[weekday].toLowerCase();
            } 
            if(_this.checkFrequency.isMonthly(hash.scheduled_task.frequency)){
                trans.period = "month";
            }
            return I18n.t('tooltip',trans);
        },
    	convertToMinOfDay : function(hours) {
    		var final_time = hours;
    		return final_time * 60;
    	},
        minToHours : function(mins) {
            var hour = mins/60;
            return hour;
        },
    	showOverviewMessage : function() {
            var _this = this;
    		var title = jQuery("#filter_name_save").val();
            var frequency = jQuery(".frequency").val();
    		var schedule_label = jQuery(".frequency option[value='" + frequency + "']").text();
    		//Time
	    	var selected_time = jQuery(".timer").val();
	    	var offset = jQuery(".clocker").val();
	    	var offset_label = offset == "1" ? "AM" : "PM" ;

    		var message = jQuery(".schedule .message");
            var text = "";

    		var base_message = {
				name : title, 
				time : selected_time + " " + offset_label + " " + HelpdeskReports.locals.account_time_zone_abbr
    		}

    		if(_this.checkFrequency.isDaily()) {
                text = I18n.t('helpdesk_reports.saved_report.message.daily_tmpl',base_message);
    		} else if(_this.checkFrequency.isMonthly()) {
                text = I18n.t('helpdesk_reports.saved_report.message.monthly_tmpl',base_message);
    		} else {
    			var day_of_week = jQuery("[name=day]:checked").val();

    			var previous_day = parseInt(day_of_week) - 1;
    			previous_day = previous_day == -1 ? 6 : previous_day;

                base_message.day = day_names[day_of_week];
                base_message.previous_day = day_names[previous_day];
                if(day_of_week != 4){
                    text = I18n.t('helpdesk_reports.saved_report.message.week_tmpl',base_message);
                } else {
                    text = I18n.t('helpdesk_reports.saved_report.message.week_friday_tmpl',base_message);
                }
            }
            message.html(text); 
    	},
    	setTwipsyContent : function(message) {
    		//Set attr and invoke setContent of twipsy
    		
    		jQuery("#schedule_filter .calendar").attr('data-original-title',message);	
    		
    		var twipsy = jQuery("#schedule_filter i").data('twipsy');
    		if(twipsy != undefined) {
    			twipsy.setContent();
    		}
    	},
        /* Utility to check frequency.
         * Will read from select or u can pass a value and check
         */
        checkFrequency : {
            isDaily : function(freq){
                var val = jQuery(".frequency").val();
                if(freq != undefined && freq == "1"){
                    return true;
                }else{
                    if(val == "1"){
                        return true;
                    }
                }
                
                return false;
            },
            isMonthly : function(freq){
                var val = jQuery(".frequency").val();
                if(freq != undefined && freq == "3"){
                    return true;
                }else{
                    if(val == "3"){
                        return true;
                    }    
                }
                
                return false;
            },
            isWeekly : function(freq){
                var val = jQuery(".frequency").val();
                if(freq != undefined && freq == "2"){
                    return true;
                }else{
                    if(val == "2"){
                        return true;
                    }    
                }
                return false;
            }
        },
        stripTags : function(text){
            if(typeof text != 'undefined'){
                return text.replace(/(<([^>]+)>)/ig,"");
            }
            return text;
        }
}
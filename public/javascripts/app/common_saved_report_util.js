/* @author  : Srihari
 * 
 * @purpose : Common functions needed by chat,phone,timesheet,customer survey reports for implementing saved reports.
 * This util contains functions taken from saved report util , and is modified to suit the above mentioned reports.
 * There will be tight coupling between this util and report specific js to build saved reports.
 * This unfriendly coupling will reduce code redundancy and maintainence.

 * @sample:refer livechat/reports.js
 *
 */
var Helpkit = Helpkit || {};

Helpkit.commonSavedReportUtil = Helpkit.commonSavedReportUtil || {};

Helpkit.commonSavedReportUtil = {

    saved_report_names : [],
    initialized : false,
    timeouts: {
        main_request: 60000
    },
    default_report_is_scheduled : false,
	default_index : -1,
	last_applied_saved_report_index : -1,
	filterChanged : false,


    /* Events for controls and dialogs are only bound here.
     * Other events are bound in report specific js.
     */
    bindCommonEvents : function() {

    	 var _this = this;
    	 
	     jQuery(document).on('click.report',"#save_filter",function(){
	     	  _this.hideTwipsy("save_filter");
	     	  _this.hideErrorMessages();
	     	  _this.hideReadMore();
	     	  _this.setDialogSubHeader();
	     	  //Modify
	     	  jQuery(".default_report_name,.colon_seperator").addClass('hide');
    		  jQuery("#filter_name_save").show();
	          //Set the value of input field
	          var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
	          current_title = 'Copy of ' + current_title;
	          jQuery("#filter_name_save").val(current_title).focus();
	          
	          is_save_op = true;
	    	  is_scheduled_op = false;
	    	  is_schedule_off = true;
	    	  create_op_for_default = false;
	    	  jQuery(".schedule").hide();

	    	  //Show disabled message for custom date ranges
	    	  if(Helpkit.presetRangesSelected) {
	            jQuery('.disabled').addClass('hide');
	    	  } else {
	             jQuery('.disabled').removeClass('hide');
	    	  }
		 });
	 		

	        jQuery(document).on('click.report',"#edit_filter",function(){
	          _this.hideTwipsy("edit_filter");
	     	  _this.hideErrorMessages();
	     	  _this.hideReadMore();
	     	   Helpkit.ScheduleUtil.modifyScheduleDialog(true);

	          //Set the value of input field
	          var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
	          jQuery("#filter_name_save").val(current_title);
	    	  is_save_op = false;
	    	  is_scheduled_op = false;
	    	  create_op_for_default = false;
	    	  jQuery(".schedule").hide();
	        });

	        jQuery(document).on('click.report',"#report-dialog-save-submit",function() {  

	          var field_val = jQuery("#filter_name_save").val().trim();   
	          if(field_val == "") {
	              jQuery("#report-dialog-save .missing_field").removeClass('hide');
	              jQuery("#report-dialog-save .unavailable_field").addClass('hide');
	            } else {
	              	jQuery("#report-dialog-save .missing_field").addClass('hide');
	          		if(is_scheduled_op && !create_op_for_default) {
          				if(_this.validateForm()){
	          				trigger_event("edit.report",{ report_type : Helpkit.report_type , isNameUpdate : false });
	          				jQuery("#report-dialog-save-cancel").click();	
	          			}else{
	          				jQuery("#report-dialog-save .missing_field").removeClass('hide');
	          			}
	          		} else {
	          			if(is_save_op) { 
	          				create_op_for_default = false;
	          				if(_this.checkNameAvailability(field_val)) {
		          				jQuery("#report-dialog-save .unavailable_field").addClass('hide');
			         	    	trigger_event("save.report",{ report_type : Helpkit.report_type });	
			               	 	jQuery("#report-dialog-save-cancel").click();
			          		} else {
			          		  jQuery("#report-dialog-save .unavailable_field").removeClass('hide');
			          		}
		          		} else {
		          			if(_this.checkNameAvailability(field_val)) {
		          				jQuery("#report-dialog-save .unavailable_field").addClass('hide');
		          				trigger_event("edit.report",{ report_type : Helpkit.report_type , isNameUpdate : true });
		          				jQuery("#report-dialog-save-cancel").click();	
		          			} else {
				          		jQuery("#report-dialog-save .unavailable_field").removeClass('hide');
				          	}
		          		}
	          		}
	            }
	        });

			jQuery(document).on('click',"#schedule_filter",function() {
				is_scheduled_op = true;
				is_schedule_off = false;
				create_op_for_default = false;
	    		jQuery(".schedule").show();
	    		_this.showReadMore();
				_this.hideTwipsy("schedule_filter");
	    		_this.hideErrorMessages();
	    		Helpkit.ScheduleUtil.modifyScheduleDialog(false);

	    		//This is for identifying whether it is a first time save for default report
	    		//to call different service methods.
	    		if(_this.last_applied_saved_report_index == -1) {
	    			if(_this.default_report_is_scheduled) {
	    				is_save_op = false;
	    			}
	    			else{
	    				is_save_op = true;
	    				create_op_for_default = true;	
	    			}
	    		} else{
	    			is_save_op = false;	
	    		}
	    		
	    		Helpkit.ScheduleUtil.constructScheduleFields(
	    			false,
	    			_this.last_applied_saved_report_index,
	    			_this.default_report_is_scheduled,
	    			_this.default_index,
	    			_this.filterChanged,
	    			Helpkit.report_filter_data,
	    			true
	    			);
	    	});
	        jQuery(document).on('click.report',"#report-dialog-delete-submit",function() {  
	             trigger_event("delete.report",{ report_type : Helpkit.report_type });
	            jQuery("#report-dialog-delete-cancel").click();
	        });
	        
	        jQuery(document).on('click.save_reports',"#report-dialog-off-submit",function() {
				is_schedule_off = true;
				jQuery("#report-dialog-save-cancel").click();
				trigger_event("edit.report",{ report_type : Helpkit.report_type , isNameUpdate : false });
			});

	        jQuery(document).on('click.report', '[data-action="update-saved-report"]', function () {
	             _this.hideTwipsy('update_filter');
	             is_scheduled_op = false;
	            trigger_event("edit.report",{ report_type : Helpkit.report_type , isNameUpdate : false });
	        });

	        jQuery(document).on('click.report', '[data-action="discard-changes"]', function () {
	            _this.hideTwipsy("discard_filter");
	            trigger_event("discard_changes.report",{ report_type : Helpkit.report_type });
	        });

	        jQuery(document).on('click.report', '[data-action="select-saved-report"]', function () {
	           var index = jQuery(this).attr('data-index');
	           trigger_event("apply.report",{ report_type : Helpkit.report_type,index : index });
	        });
    },
    validateForm : function() {
		var _isvalid = true;
		if(is_scheduled_op) {
			var subject = jQuery(".schedule .subject").val();
			var desc = jQuery(".desc").val();
			var email_data = jQuery(".email").select2('data');
			if(!(email_data.length > 0 && subject != "" && desc != "")){
				jQuery("#report-dialog-save .missing_field").removeClass('hide');
				_isvalid = false;
			}else{
				jQuery("#report-dialog-save .missing_field").addClass('hide');
			}
		} 
		return _isvalid;
	},
	hideReadMore : function() {
	    	jQuery(".read_more").addClass('hide');
    },
    showReadMore : function() {
    	jQuery(".read_more").removeClass('hide');
    },
    hideErrorMessages : function(){
	    	jQuery("#report-dialog-save .unavailable_field").addClass('hide');
	     	jQuery("#report-dialog-save .missing_field").addClass('hide');
	},
	setDialogSubHeader : function(){
			jQuery("#report-dialog-save .modal-header").append("<p class='visibility'>" + I18n.t('helpdesk_reports.saved_report.dialog_sub_header') + "</p>");

			if(Helpkit.enable_schedule_report && Helpkit.presetRangesSelected){
	    		jQuery("#report-dialog-save .modal-header").append("<p class='visibility'>" + I18n.t('helpdesk_reports.saved_report.dialog_schedule_guide') + "</p>");
	    	}
	},
    checkNameAvailability : function(name) {
    	if(is_save_op) {
    		if(!this.filterChanged && this.last_applied_saved_report_index == -1){
    			return true;
	    	}

	    	if(jQuery.inArray(name.toLowerCase(),this.saved_report_names) != -1){
	    		return false;
	    	}	
    	} else {
    		if(this.last_applied_saved_report_index != -1) {
    			var old_name = Helpkit.report_filter_data[this.last_applied_saved_report_index].report_filter.filter_name;
		    	var temp = this.saved_report_names.slice();
		    	var index = temp.indexOf(old_name);
				temp.splice(index, 1); 
				if(jQuery.inArray(name.toLowerCase(),temp) != -1){
		    		return false;
		    	} else{
		    		return true;
		    	}
	    	} 
    	}
    	return true;
     },
     setActiveSavedReport : function(el){
       jQuery("#report-title").html(escapeHtml(jQuery(el).attr('data-title')));
       //Remove previous active
       jQuery(".reports-menu li.active").removeClass('active');
       jQuery(el).parent().addClass('active');
	 },
     controls : {
	        showSaveOptions : function(last_applied_index) {
	            jQuery(".report-title-block").addClass('changed');
	            jQuery(".unsaved_star").removeClass('hide');
	            //show saveas and discard changes icon
	            
	            jQuery("#discard_filter").removeClass('hide');
	            jQuery("#save_filter").removeClass('hide');
	            
	            //console.log(this.last_applied_saved_report_index);
	            if(last_applied_index == -1) {
	                jQuery("#update_filter").addClass('hide');  
	                jQuery("#discard_filter,#update_filter").removeClass('pull-left');
	            }else{
	                jQuery("#update_filter").removeClass('hide');
	                jQuery("#discard_filter,#update_filter").addClass('pull-left');
	            }
	        },
	        hideSaveOptions : function() {
	             jQuery(".report-title-block").removeClass('changed');
	             jQuery(".unsaved_star").addClass('hide');
	             jQuery("#save_filter").addClass('hide');
	             jQuery("#discard_filter").addClass('hide');
	             jQuery("#update_filter").addClass('hide')
	        },
	        showDeleteAndEditOptions : function() {
	             jQuery("#edit_filter").removeClass('hide');
	             jQuery("#delete_filter").removeClass('hide');
	        },
	        hideDeleteAndEditOptions : function() {
	             jQuery("#edit_filter").addClass('hide');
	             jQuery("#delete_filter").addClass('hide');
	        },
	        showScheduleOptions : function(withBorder){
	        	jQuery("#schedule_filter").removeClass('hide');
	        	if(withBorder){
	        		jQuery("#schedule_filter").addClass('left-border right-border');
	        	} else{
	        		jQuery("#schedule_filter").removeClass('left-border right-border');
	        	}
	        },
	        hideScheduleOptions : function(){
	        	jQuery("#schedule_filter").addClass('hide').removeClass('left-border right-border');
	        }
	    },
	    populateSavedReports : function(index) {
	            var hash = Helpkit.report_filter_data;
	            var _this = this;
	            var rows = [];
	            _this.saved_report_names = [];
	            if( hash != undefined) {
	            	jQuery.each(hash, function(index, val) {
		                var option = {};
		                var report_filter = val.report_filter;
		                if(report_filter.data_hash.hasOwnProperty('default_report_is_scheduled')){
		            		_this.default_report_is_scheduled = true;
		            		_this.default_index = index;
		            		//if this report was scheduled show it
		                    
		                    if(report_filter.data_hash.schedule_config.enabled){
	                    		Helpkit.ScheduleUtil.displayScheduleStatus(true,Helpkit.ScheduleUtil.getTooltipMessage(report_filter.data_hash.schedule_config));
		                    } else{
		                    	Helpkit.ScheduleUtil.displayScheduleStatus(false);
		                    }
		            		//return true;
		            	} else{
		            		option.id = index; //id is populated in front end to identify ith saved report filter.
			                option.text = report_filter.filter_name;
			                _this.saved_report_names.push(report_filter.filter_name.toLowerCase());
			                rows.push(option);
		            	}
	            	});	
	            }
	            var report_title,report_icon;
	            if(Helpkit.report_type == "phone_summary") {
	            	report_title = "helpdesk_reports.phone_summary.title" ;
	            	report_icon = "ficon-phone_summary" ;
	            } else if(Helpkit.report_type == "chat_summary") {
	            	report_title = "helpdesk_reports.chat_summary.title" ;
	            	report_icon = "ficon-live_chat" ;
	            } else if(Helpkit.report_type == "timesheet_reports") {
	            	report_title = "helpdesk_reports.timesheet_reports.title";
	            	report_icon = "ficon-time_sheet" ;
	            } else if(Helpkit.report_type == "satisfaction_survey") {
	            	report_title = "helpdesk_reports.satisfaction_survey.title";
	            	report_icon = "ficon-customer_satisfaction" ;	            	
	            }

	            var tmpl = JST["helpdesk_reports/templates/saved_report_menu_other"]({ 
	                data: rows,
	                report_title : report_title,
	                report_icon : report_icon
	            });
	            jQuery(".reports-menu").html(tmpl);
	            //Set active
	            jQuery(".reports-menu li a[data-index=" + index +"]").parent().addClass('active');

	            var report_name = I18n.t(report_title,{defaultValue: 'report' });
	            if(report_name != undefined){
	            	report_name = report_name.toLowerCase();
	            }
	            _this.saved_report_names.push(report_name);
	            _this.showReportDropdown();
	    },
	    showReportDropdown : function() {
	    	 //Show dropdown icon only when saved reports are available
	    	var _this = this;
            var hash = Helpkit.report_filter_data;
            if(hash.length == 0 || ( hash.length == 1 && _this.default_report_is_scheduled)){
            	jQuery('.report-title-block #report-title').css('cursor','auto');
            	jQuery('.title-dropdown').css('display', 'none');
            } else {
            	jQuery('.report-title-block #report-title').css('cursor','pointer'); 
            	jQuery('.title-dropdown').css('display', 'inline-block');
            }
	    },
	    /* Utils */
	    makeAjaxRequest: function (args) {
	        args.url = args.url;
	        args.type = args.type ? args.type : "POST";
	        args.dataType = args.dataType ? args.dataType : "json";
	        args.data = args.data;
	        args.success = args.success ? args.success : function () {};
	        args.error = args.error ? args.error : function () {};
	        var _request = jQuery.ajax(args);
   		},
   		dateRangeDiff: function (date_range_param) {
	        var diff = 0;
            var date_range = date_range_param.split('-');
	        if (date_range.length == 2){
	            diff = (Date.parse(date_range[1]) - Date.parse(date_range[0])) / (36e5 * 24);
	        }
	        if (date_range.length == 1){
         	   diff = (new Date().setHours(0,0,0,0) - Date.parse(date_range[0])) / (36e5 * 24);
        	}
	        return diff;
	    },
	    convertDateDiffToDate: function (dateDiff) {
	        var dateFormat = getDateFormat('mediumDate')   
	        var date_lag   = 0;
	        var today      = new Date();
	        var endDate    = new Date(today.setDate(today.getDate()-date_lag));
	        var startDate  = new Date(today.setDate(today.getDate()-(dateDiff+date_lag) ));
	        if (dateDiff == 0){
	            return endDate.toString(dateFormat);
	        }
	        else {
	            return startDate.toString(dateFormat) + " - " + endDate.toString(dateFormat);
	        }
    	},
    	convertPresetRangesToDate : function(diff,period) {
        
	        var dateFormat = getDateFormat('mediumDate').toUpperCase();   
	        var date_lag   = 0;//Helpkit.date_lag;
	        var date_const = Helpkit.DateRange;
	        moment.lang('en');
	        var date_ranges = this.getDateRangeDefinition(dateFormat,date_lag);

	        //For exisiting saved reports
	        if(period == undefined) {
	            return this.convertDateDiffToDate(diff);
	        }

	        if(period == date_const.TODAY) {
            	return date_ranges['endDate'];
        	} else if(period == date_const.YESTERDAY) {
            	return date_ranges['1'];
        	} else if(period == date_const.LAST_7) {
	            return date_ranges[7] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.LAST_30) {
	            return date_ranges[30] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.LAST_90) {
	            return date_ranges[90] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.THIS_WEEK) {
	            return date_ranges['this_week_start'] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.PREVIOUS_WEEK) {
	            return date_ranges['previous_week_start'] + " - " + date_ranges['previous_week_end'];
	        } else if(period == date_const.THIS_MONTH) {
	            return date_ranges['this_month_start'] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.PREVIOUS_MONTH) {
	            return date_ranges['previous_month_start'] + " - " + date_ranges['previous_month_end'];
	        } else if(period == date_const.LAST_3_MONTHS) {
	            return date_ranges['last_3_months'] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.LAST_6_MONTHS) {
	            return date_ranges['last_6_months'] + " - " + date_ranges['endDate'];
	        } else if(period == date_const.THIS_YEAR) {
	            return date_ranges['this_year_start'] + " - " + date_ranges['endDate'];
	        } 
    	},
    	getDateRangeDefinition : function(dateFormat,date_lag){
	        moment.lang('en');
	        return {
	            1:                    moment().subtract((1   + date_lag),"days").format(dateFormat), 
	            7:                    moment().subtract((6   + date_lag),"days").format(dateFormat),
	            30:                   moment().subtract((29  + date_lag),"days").format(dateFormat),
	            90:                   moment().subtract((89  + date_lag),"days").format(dateFormat),
	            endDate:              moment().subtract(date_lag,"days").format(dateFormat),
	            this_week_start:      moment().startOf('isoWeek').format(dateFormat),
	            previous_week_start:  moment().subtract(1, 'weeks').startOf('isoWeek').format(dateFormat),
	            previous_week_end:    moment().subtract(1, 'weeks').endOf('isoWeek').format(dateFormat),
	            this_month_start:     moment().startOf('month').format(dateFormat),
	            previous_month_start: moment().subtract(1,'months').startOf('month').format(dateFormat),
	            previous_month_end:   moment().subtract(1,'months').endOf('month').format(dateFormat),
	            last_3_months:        moment().subtract(2,'months').startOf('month').format(dateFormat),
	            last_6_months:        moment().subtract(5,'months').startOf('month').format(dateFormat),
	            this_year_start:      moment().startOf('year').format(dateFormat)
	        };
    	},
    	showResponseMessage: function(message){
	        jQuery("#email_reports_msg").remove();
	        var msg_dom = jQuery("#noticeajax");
	        msg_dom.empty();
	        msg_dom.prepend(message);
	        msg_dom.show();
	        jQuery("<a />").addClass("close").attr("href", "#").appendTo(msg_dom).on('click.helpdesk_reports', function(){
	            msg_dom.fadeOut(600);
	            return false;
	        });
	        setTimeout(function() {    
	            jQuery("#noticeajax a").trigger( "click" );  
	            msg_dom.find("a").remove();
	        }, 2000);
	        
	    },
    	/* Services Helpers */
    	saveHelper : function(opts) {
    		
    		var _this = this;
    		opts.params.filter_name = _this.escapeString(jQuery("#filter_name_save").val());
    		opts.params.data_hash.schedule_config = Helpkit.ScheduleUtil.getScheduleParams();

			var ajaxOpts = {
	              url: opts.url,
	              type: 'POST',
	              contentType: 'application/json',
	              data: Browser.stringify(opts.params),
	              timeout: _this.timeouts.main_request,
	              success: function (resp) {

	                      //update report_filter_data 
	                      var obj = {};
	                      obj.report_filter = {};
	                      obj.report_filter.filter_name = resp.filter_name;
	                      obj.report_filter.id = resp.id;
	                      obj.report_filter.data_hash = resp.data;
	                      Helpkit.report_filter_data.push(obj);
	                      var default_report_is_scheduled = resp.data.default_report_is_scheduled;

	                      if(default_report_is_scheduled != undefined) {
		                    	
		                    	_this.default_report_is_scheduled = true;
	                        	_this.default_index = Helpkit.report_filter_data.length - 1; 
	                        	_this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.schedule_success',{ defaultValue : 'Report has been Scheduled Successfully'}));
	                        
	                       } else {
			                        //push a new li element into menu
			                      var new_id = Helpkit.report_filter_data.length - 1; 
			                      var tmpl = JST["helpdesk_reports/templates/saved_report_row_tmpl"]({ 
			                          index : new_id,
			                          title : resp.filter_name
			                      });
			                      jQuery(tmpl).insertAfter(".reports-menu ul li.seperator");
			                      _this.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + new_id +"]"));
			                      _this.saved_report_names.push(resp.filter_name.toLowerCase());
			                      //update the last applied filter
			                      _this.last_applied_saved_report_index = new_id;

			                      _this.controls.showDeleteAndEditOptions();
			                      if(resp.data.date.presetRange) {
			                      	_this.controls.showScheduleOptions(false);
			                      }else{
			                      	_this.controls.hideScheduleOptions();	
			                      }
			                      _this.controls.hideSaveOptions();
			                      _this.filterChanged = false;

			                      if(Helpkit.report_filter_data.length == 0) {
			                        jQuery(".saved_reports_list .seperator").addClass('hidden');
			                      } else {
			                      	jQuery(".saved_reports_list .seperator").removeClass('hidden');
			                      }
			                       
			                      this.new_id = new_id;
			                      opts.callbacks.success.call(this);

			                      //Show successfully saved message
			                      _this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.saved_message'));
			                      _this.cacheLastAppliedReport(resp.id);
			                      _this.showReportDropdown();
	                  		}
	                  		 //if this report was scheduled show it
		                    if(resp.data.schedule_config.enabled){
		                    	Helpkit.ScheduleUtil.displayScheduleStatus(true,Helpkit.ScheduleUtil.getTooltipMessage(resp.data.schedule_config));
		                    } else{
		                    	Helpkit.ScheduleUtil.displayScheduleStatus(false);
		                    }
	              },
	              error: function (xhr,exception) {
	                  if(xhr.status == 422) {
	                 	_this.showResponseMessage(JSON.parse(xhr.responseText)['errors']);
	            	  } else{
	            		_this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.save_failed_message'));
	            	  }
	                  opts.callbacks.error.call(this);
	              }
	          };

	          _this.makeAjaxRequest(ajaxOpts);
    	},
    	updateHelper : function(opts){
		  var _this = this;
          var ajaxOpts = {
              url: opts.url,
              type: 'POST',
              contentType: 'application/json',
              data: Browser.stringify(opts.params),
              timeout: _this.timeouts.main_request,
              success: function (resp) {
                      //update one array -> report_filter_data
                      var obj = {};
                      obj.report_filter = {};
                      obj.report_filter.filter_name = resp.filter_name;
                      obj.report_filter.data_hash = resp.data;
                      obj.report_filter.id = resp.id;
                      Helpkit.report_filter_data[opts.current_selected_index] = obj;

                      if(_this.last_applied_saved_report_index != -1) {
                      		  _this.filterChanged = false;
		                      _this.controls.hideSaveOptions();
		                      if(resp.data.date.presetRange) {
		                      	_this.controls.showScheduleOptions(false);
		                      } else {
		                      	_this.controls.hideScheduleOptions();
		                      }
		                      
		                      _this.controls.showDeleteAndEditOptions();

		                      _this.populateSavedReports(opts.current_selected_index);
		                      _this.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + opts.current_selected_index +"]"));

		                      //Update the used names array
		                      var index = _this.saved_report_names.indexOf(opts.params.filter_name);
		                      if (index > -1) {
		                          _this.saved_report_names[index] = resp.filter_name.toLowerCase();
		                      }

                      }
                     
                      //if this report was scheduled show it
                    if(resp.data.schedule_config.enabled){
                    	Helpkit.ScheduleUtil.displayScheduleStatus(true,Helpkit.ScheduleUtil.getTooltipMessage(resp.data.schedule_config));
                    } else{
                    	Helpkit.ScheduleUtil.displayScheduleStatus(false);
                    }
                      //Show successfully updated message
                      _this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.updated_message'));
                      opts.callbacks.success.call(this);
                  
              },
              error: function (xhr,exception) {
	            	if(xhr.status == 422){
	            		_this.showResponseMessage(JSON.parse(xhr.responseText)['errors']);
	            	} else{
	            		_this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.update_failed_message'));
	            	}
	            	opts.callbacks.error.call(this);
	            }
          };
          _this.makeAjaxRequest(ajaxOpts);
    	},
    	deleteHelper : function(opts) {
		          
		      var _this = this;
	          var ajaxOpts = {
	              url: opts.url,
	              type: 'POST',
	              dataType : 'text',
	              data: {
	                  id : Helpkit.report_filter_data[opts.current_selected_index].report_filter.id 
	              },
	              timeout: _this.timeouts.main_request,
	              success: function (resp) {
	                    //update -> report_filter_data & menu
	                    Helpkit.report_filter_data.splice(opts.current_selected_index,1);
	                    _this.populateSavedReports(-1);

	                    if(Helpkit.report_filter_data.length == 0){
	                      jQuery(".saved_reports_list .seperator").addClass('hidden');
	                    }
	                    //Show successfully deleted message
	                    _this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.deleted_message'));
	                    opts.callbacks.success.call(this);
	              },
	              error: function (data) {
	                  _this.showResponseMessage(I18n.t('helpdesk_reports.saved_report.deleted_failed_message'));
	              	  opts.callbacks.error.call(this);
	              }
	          };
			  _this.makeAjaxRequest(ajaxOpts);
    	},
    	cacheLastAppliedReport : function(index){
			 if (typeof (Storage) !== "undefined") {
	            //Storing the index of visited report to retain it.
	            window.localStorage.setItem(Helpkit.report_type,index);
	         }    		
    	},
    	applyLastCachedReport : function(){
	        if (typeof (Storage) !== "undefined" && localStorage.getItem(Helpkit.report_type) !== null) {
	            var index = this.getDataIndex(JSON.parse(localStorage.getItem(Helpkit.report_type)));
	            if(index != -1){
	            	//this.applySavedReport(index);
	            	setTimeout(function(){
	            		jQuery("li a[data-index=" + index +"]").trigger('click');
	            		jQuery(".reports-menu").addClass('hide');
	            	},100);
	            }
	        } 
    	},
    	escapeString : function(name){
    		return name != undefined ? escapeHtml(name).replace(/'/g, '&apos;') : name;
    	},

    	hideTwipsy : function(container){
    		var twipsy = jQuery("#" + container + " i ").data('twipsy');
    		if(twipsy != undefined) {
    			twipsy.hide();
    		}
    	},
    	/* Used for identifying index from cached id */
    	getDataIndex : function(id){
    		var hash = Helpkit.report_filter_data;
    		var index = -1;
    		if (hash != undefined) {
    			jQuery.each(hash,function(idx,obj){
    				if(obj.report_filter.id == id){
    					index = idx;
    				}	
    			});	
    		}
    		return index;
    	},
    	/* Entry point */
	    init : function() {
	    	if(!this.initialized){
	    		this.saved_report_names = [];
		    	this.bindCommonEvents();
	       		this.populateSavedReports(-1);
       			this.initialized = true;	
	    	}
	    }
}
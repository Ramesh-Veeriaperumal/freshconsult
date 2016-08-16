HelpdeskReports.SavedReportUtil = HelpdeskReports.SavedReportUtil || {};

/* Global Variables
*  is_save_op - used to determine whether save or update
*  is_schedule_op - set to true when scheduling operation & false during first time save
*  is_schedule_off - When false, we pass schedule config false
*  create_op_for_default - Determines whether this is the first time default report 
						is being scheduled
*/
HelpdeskReports.SavedReportUtil = (function() {

	var _FD = 	{
	    last_applied_saved_report_index : -1,
	     CONST: {
	        save_report   : "/save_reports_filter",
	        delete_report : "/delete_reports_filter",
	        update_report : "/update_reports_filter"
	    },
	    filterChanged : false,
	    initialized : false,
	    saved_report_names : [],
	    default_report_is_scheduled : false,
	    default_index : -1,
	    bindEvents : function() {
	    	var _this = this;
	    	jQuery(document).on('click.save_reports',"#save_filter",function(){
	    		_FD.hideTwipsy("save_filter");
	    		_FD.hideErrorMessages();
	    		_FD.hideReadMore();
	    		_FD.setDialogSubHeader();
	     	    //Modify
	     	    jQuery(".default_report_name,.colon_seperator").addClass('hide');
    			jQuery("#filter_name_save").show();
	    		//Set the value of input field
	    		var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
	    		current_title = I18n.t('helpdesk_reports.saved_report.copy_of') + current_title;
	    		jQuery("#filter_name_save").val(current_title);
	    		//Removing Schedule section for save operation
	    		is_save_op = true;
	    		is_scheduled_op = false;
	    		is_schedule_off = true;
	    		create_op_for_default = false;
	    		jQuery(".schedule").hide();

	    		//Show disabled message for custom date ranges
	    		if(HelpdeskReports.locals.presetRangesSelected) {
                	 jQuery('.disabled').addClass('hide');
	    		} else {
                 	jQuery('.disabled').removeClass('hide');
	    		}
	    	});

	    	jQuery(document).on('click.save_reports',"#edit_filter",function(){
	    		_FD.hideTwipsy("edit_filter");
	    		_FD.hideErrorMessages();
	    		_FD.setDialogSubHeader();
	    		_FD.hideReadMore();
	     	    Helpkit.ScheduleUtil.modifyScheduleDialog(true);
	    		//Set the value of input field
	    		var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
	    		jQuery("#filter_name_save").val(current_title);
	    		//Removing Schedule section for edit operation
	    		is_save_op = false;
	    		is_scheduled_op = false;
	    		create_op_for_default = false;
	    		jQuery(".schedule").hide();
	    	});

	    	jQuery(document).on('click.save_reports',"#schedule_filter",function() {
	    		is_scheduled_op = true;
	    		is_schedule_off = false;
	    		create_op_for_default = false;
	    		jQuery(".schedule").show();
	    		_FD.hideTwipsy("schedule_filter");
	    		_FD.hideErrorMessages();
	    		_FD.showReadMore();
	    		Helpkit.ScheduleUtil.modifyScheduleDialog(false);
	    		//This is for identifying whether it is a first time save for default report
	    		//to call different service methods.
	    		if(_FD.last_applied_saved_report_index == -1) {
	    			if(_FD.default_report_is_scheduled) {
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
	    			HelpdeskReports.locals.report_filter_data,
	    			true
	    			);
	    	});

			jQuery(document.body).on("change","#custom_field_group_by select",function(){
				_this.filterChanged = true;
				_FD.controls.hideDeleteAndEditOptions();
				_FD.controls.hideScheduleOptions();
				_FD.controls.showSaveOptions(_FD.last_applied_saved_report_index);
			});

	    	//Saved Reports
	        jQuery(document).on('click.save_reports',"#report-dialog-save-submit",function() {  

	        	var field_val = Helpkit.ScheduleUtil.stripTags(jQuery("#filter_name_save").val().trim());   
	         	if(field_val == "") {
	            	jQuery("#report-dialog-save .missing_field").removeClass('hide');
	            	jQuery("#report-dialog-save .unavailable_field").addClass('hide');
	          	} else {
	          		jQuery("#report-dialog-save .missing_field").addClass('hide');
	          		if(is_scheduled_op && !create_op_for_default) {
          				if(_FD.validateForm()){
	          				_FD.updateSavedReport(false);
	          				jQuery("#report-dialog-save-cancel").click();	
	          			}else{
	          				jQuery("#report-dialog-save .missing_field").removeClass('hide');
	          			}
	          		} else {
	          			if(is_save_op) {
	          				create_op_for_default = false;
	          				if(_FD.checkNameAvailability(field_val)) {
		          				jQuery("#report-dialog-save .unavailable_field").addClass('hide');
			         	    	_FD.saveReport();	
			               	 	jQuery("#report-dialog-save-cancel").click();
			          		} else {
			          		  jQuery("#report-dialog-save .unavailable_field").removeClass('hide');
			          		}
		          		} else {
		          			if(_FD.checkNameAvailability(field_val)) {
		          				jQuery("#report-dialog-save .unavailable_field").addClass('hide');
		          				_FD.updateSavedReport(true);
		          				jQuery("#report-dialog-save-cancel").click();	
		          			} else {
				          		jQuery("#report-dialog-save .unavailable_field").removeClass('hide');
				          	}
		          		}
	          		}
	          		
	          	}
	        });
			
			jQuery(document).on('click.save_reports',"#report-dialog-off-submit",function() {
				is_schedule_off = true;
				jQuery("#report-dialog-save-cancel").click();
				_FD.updateSavedReport(false);
			});

	        jQuery(document).on('click',"#report-dialog-delete-submit",function() {  
	        		 _FD.deleteSavedReport();
	        		jQuery("#report-dialog-delete-cancel").click();
	        });

	        jQuery('#reports_wrapper').on('click.save_reports', '[data-action="update-saved-report"]', function () {
	            _FD.hideTwipsy('update_filter');
	            is_scheduled_op = false;
	            _FD.updateSavedReport(false);
	        });

	        jQuery('#reports_wrapper').on('click.save_reports', '[data-action="discard-changes"]', function () {
	           	_FD.hideTwipsy("discard_filter");
	            _FD.discardChangesMadeToFilter();
	        });

	        jQuery('#reports_wrapper').on('click.save_reports', '[data-action="select-saved-report"]', function () {
	           var index = jQuery(this).attr('data-index');
	            jQuery('#loading-box').show();
	           setTimeout(function(){
	           		_FD.applySavedReport(index,true); 
	           },1000);
	        });
	        jQuery('#reports_wrapper').on('change', '[data-type="filter-field"]', function () { 
	            _FD.filterChanged = true;
	            HelpdeskReports.locals.saved_report_used = false;
	        });
	        jQuery(document).on("report_refreshed",function(ev,data){
	        	if(_FD.filterChanged) {
	        		 _FD.controls.hideDeleteAndEditOptions();
	        		 _FD.controls.hideScheduleOptions();
	           		 _FD.controls.showSaveOptions(_FD.last_applied_saved_report_index);	
	        	}
	        });
	        jQuery(document).on("filter_changed",function(ev,data){
	        	_FD.filterChanged = true;
	        	HelpdeskReports.locals.saved_report_used = false;
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
	    hideErrorMessages : function(){
	    	jQuery("#report-dialog-save .unavailable_field").addClass('hide');
	     	jQuery("#report-dialog-save .missing_field").addClass('hide');
	    },
	    setDialogSubHeader : function(){
	    	jQuery("#report-dialog-save .modal-header").append("<p class='visibility'>" + I18n.t('helpdesk_reports.saved_report.dialog_sub_header') + "</p>");

	    	if(HelpdeskReports.locals.enable_schedule_report && HelpdeskReports.locals.presetRangesSelected){
	    		jQuery("#report-dialog-save .modal-header").append("<p class='visibility'>" + I18n.t('helpdesk_reports.saved_report.dialog_schedule_guide') + "</p>");
	    	}
	    },
	    hideReadMore : function() {
	    	jQuery(".read_more").addClass('hide');
	    },
	    showReadMore : function() {
	    	jQuery(".read_more").removeClass('hide');
	    },
	    saveReport : function() {
	        var _this = this;
	        var params = {};
	        params.data_hash = {};
	        var locals = HelpdeskReports.locals;

	        params.data_hash.date = {};
	        if(locals.presetRangesSelected) {
	        	params.data_hash.date.date_range = _FD.core.dateRangeDiff(locals.date_range);
	        	params.data_hash.date.presetRange = true;
	        	params.data_hash.date.period = HelpdeskReports.locals.presetRangesPeriod;
	        } else {
	        	params.data_hash.date.date_range = locals.date_range;
	        	params.data_hash.date.presetRange = false;
	        }
	       
	       	params.data_hash.select_hash = locals.select_hash;
	        params.data_hash.report_filters = locals.local_hash.splice(0);
	        params.filter_name = _this.escapeString(jQuery("#filter_name_save").val());

	        _FD.attachExtraParamsPerReport(params.data_hash);
	        params.data_hash.schedule_config = Helpkit.ScheduleUtil.getScheduleParams();
	        
	        //set the params only when schedule button on default report was clicked.
	        //if index is only used, we miss out scenario in which filter was edited when 
	        //default report was applied.
	        if(_FD.last_applied_saved_report_index == -1 && !_FD.filterChanged) {
	        	params.data_hash.default_report_is_scheduled = true;
	        } 
	        if(locals.report_type == "glance" && locals.active_custom_field){
	            params["active_custom_field"] = locals.active_custom_field;
	        }
	        var opts = {
	            url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + _FD.CONST.save_report,
	            type: 'POST',
	            contentType: 'application/json',
	            data: Browser.stringify(params),
	            timeout: _FD.core.timeouts.main_request,
	            success: function (resp) {
	                    //update report_filter_data
	                    var obj = {};
	                    obj.report_filter = {};
	                    obj.report_filter.filter_name = resp.filter_name;
	                    obj.report_filter.id = resp.id;
	                    //bad response object structure
	                    obj.report_filter.data_hash = resp.data;
	                    HelpdeskReports.locals.report_filter_data.push(obj);
	                    var default_report_is_scheduled = resp.data.default_report_is_scheduled;

	                     if(default_report_is_scheduled != undefined) {
		                    	
	                    	_this.default_report_is_scheduled = true;
                        	_this.default_index = HelpdeskReports.locals.report_filter_data.length - 1; 
                        	HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.schedule_success'));
	                        
	                     } else {
		                     	//push a new li element into menu
		                    var new_id = HelpdeskReports.locals.report_filter_data.length - 1; 
		                    var tmpl = JST["helpdesk_reports/templates/saved_report_row_tmpl"]({ 
		                        index : new_id,
		                        title : resp.filter_name
		                    });
		                    jQuery(tmpl).insertAfter('.reports-menu ul li.seperator');
		                    _FD.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + new_id +"]"));
		                    _FD.saved_report_names.push(resp.filter_name.toLowerCase());
		                    //update the last applied filter
		                    _FD.last_applied_saved_report_index = new_id;

		                    _FD.controls.showDeleteAndEditOptions();
		                    if(resp.data.date.presetRange) {
		                   		 _FD.controls.showScheduleOptions(false);
		                   	} else {
		                   		 _FD.controls.hideScheduleOptions();
		                   	}
		                    _FD.controls.hideSaveOptions();
		                    _FD.filterChanged = false;

		                    if(HelpdeskReports.locals.report_filter_data.length > 0){
		                    	jQuery(".saved_reports_list .seperator").removeClass('hidden');
		                    }
		                     //Show successfully saved message
		                    HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.saved_message'));
		                    _this.cacheLastAppliedReport(resp.id);
		                    _this.showReportDropdown();
		                    
	                     }
	                     if(resp.data.schedule_config.enabled){
	                    	Helpkit.ScheduleUtil.displayScheduleStatus(true,Helpkit.ScheduleUtil.getTooltipMessage(resp.data.schedule_config));
		                 } else{
		                    Helpkit.ScheduleUtil.displayScheduleStatus(false);
		                 }
	                    
	            },
	            error: function (xhr,exception) {
	            	if(xhr.status == 422){
	            		HelpdeskReports.CoreUtil.showResponseMessage(JSON.parse(xhr.responseText)['errors']);
	            	} else{
	            		HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.save_failed_message'));
	            	}
	            }
	        };
	        _FD.core.makeAjaxRequest(opts);
	    },
	    populateSavedReports : function(index) {
	            var hash = HelpdeskReports.locals.report_filter_data;
	            var _this = this;
	            var rows = [];
	            _FD.saved_report_names = [];
	            
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
		                _FD.saved_report_names.push(report_filter.filter_name.toLowerCase());
		                rows.push(option);
	            	}
	            });

	            var tmpl = JST["helpdesk_reports/templates/saved_report_menu_tmpl"]({ 
	                data: rows,
	                report_title : HelpdeskReports.locals.report_type + '.title'
	            });
	            jQuery(".reports-menu").html(tmpl);
	            //Set active
	            jQuery(".reports-menu li a[data-index=" + index +"]").parent().addClass('active');

	            //Add report name to used array
	            var report_name = I18n.t(HelpdeskReports.locals.report_type + '.title',{scope: 'helpdesk_reports', defaultValue: HelpdeskReports.locals.report_type });
	            if(report_name != undefined){
	            	report_name = report_name.toLowerCase();
	            }
	            _FD.saved_report_names.push(report_name);
	            _FD.showReportDropdown();
	    },
	    showReportDropdown : function() {
	    	 //Show dropdown icon only when saved reports are available
	    	var _this = this;
            var hash = HelpdeskReports.locals.report_filter_data;;
            if(hash.length == 0 || ( hash.length == 1 && _this.default_report_is_scheduled)){
            	jQuery('.report-title-block #report-title').css('cursor','auto');
            	jQuery('.title-dropdown').hide();
            } else {
            	jQuery('.report-title-block #report-title').css('cursor','pointer'); 
            	jQuery('.title-dropdown').show();
            }
	    },
	    setActiveSavedReport : function(el){
	           jQuery("#report-title").html(escapeHtml(jQuery(el).attr('data-title')));
	           //Remove previous active
	           jQuery(".reports-menu li.active").removeClass('active');
	           jQuery(el).parent().addClass('active');
	    },
	    applySavedReport : function(index,refresh) {

	        var hash = HelpdeskReports.locals.report_filter_data;
	        var _this = this;
	        var invalid_params_found = false;
	        var is_preset_selected = false;
	         var id = -1;
	        _FD.flushAppliedFilters();
	        _FD.last_applied_saved_report_index = index;

	        if(index != -1) {
	            var filter_hash = hash[index].report_filter;
	            HelpdeskReports.locals.active_custom_field = filter_hash.data_hash.active_custom_field;
	            HelpdeskReports.locals.default_custom_field = filter_hash.data_hash.active_custom_field;
	            id = filter_hash.id;
	            var date_hash = filter_hash.data_hash.date;
	            var daterange;
	            //Set the date range from saved range
	            if(date_hash.presetRange) {
	            	daterange = _FD.core.convertPresetRangesToDate(date_hash.period,date_hash.date_range);
	           		HelpdeskReports.locals.presetRangesSelected = true;
	           		HelpdeskReports.locals.presetRangesPeriod = date_hash.period;
	           		is_preset_selected = true;
	            } else {
	            	daterange = date_hash.date_range;
	            	HelpdeskReports.locals.presetRangesSelected = false;
	            	is_preset_selected = false;
	            }
	            
	            jQuery('#date_range').val(daterange);
	            

	            if(filter_hash.data_hash.report_filters != null) {
	                jQuery.each(filter_hash.data_hash.report_filters, function(index, filter_row) {

	                 var condition = filter_row.condition;

                 	if(jQuery.inArray(condition,_FD.core.filter_remote) != -1) {

                 		var saved_source = filter_row.source;
                 		if (filter_row.value.length) {

							var values = filter_row.value.split(','); // val1,val2,val3 -> [val1,val2,val3]
							jQuery.each(values,function(idx,val) {
								var is_saved_param_valid = _FD.checkValidityOfSavedParams(condition,val,saved_source);
								if(!is_saved_param_valid) {
									//source object was spliced in reponse of elastic search itself
									values.splice(idx,1);
									invalid_params_found = true;
								}
							});        

							jQuery('#' + condition).select2('destroy');
	                    	jQuery('#' + condition).select2(_FD.core.getRemoteFilterConfig(condition,true,saved_source));
	                    	jQuery("#" + condition).select2('val', values);

                 		}

                	 } else {

	                   	if (filter_row.value && filter_row.value.length) {
	                   		var values;
	                   		if(jQuery.isArray(filter_row.value)) {
	                   			//For Nested fields , values is already an array
	                   			values = filter_row.value;
	                   		} else {
	                   			 values = filter_row.value.split(','); // val1,val2,val3 -> [val1,val2,val3]
	                   			 //Identifying invalid params for neseted fields is not working,because all values are
	                   			 //grouped under same condition, when fixed move the below logic out of the if else.
	                   			 jQuery.each(values,function(idx,val) {
									var is_saved_param_valid = _FD.checkValidityOfSavedParams(condition,val);
									if(!is_saved_param_valid) {
										//source object was spliced in reponse of elastic search itself
										values.splice(idx,1);
										invalid_params_found = true;
									}
								});	
	                   		}
							 
							if(jQuery.inArray(condition,_FD.core.default_available_filter) != -1){
								jQuery("#" + condition).select2('val', values);
							} else{
								if(jQuery.isArray(filter_row.value)){
	                   				_FD.core.constructReportField(condition,values);
	                   			}else{
	                   				_FD.core.constructReportField(condition,values.toString());
	                   			}
									
							}
	                   		 
						}
	                   	
	                 }
                 
	              });
	            }
	            is_scheduled_op = false;
	        } else{
	        	var default_date_range = _FD.core.convertDateDiffToDate(29);
	        	jQuery('#date_range').val(default_date_range);
	        	HelpdeskReports.locals.presetRangesSelected = true;
                HelpdeskReports.locals.presetRangesPeriod = 'last_30';
                HelpdeskReports.locals.active_custom_field = _.keys(HelpdeskReports.locals.custom_field_hash).first();
                HelpdeskReports.locals.default_custom_field = HelpdeskReports.locals.active_custom_field;
	        }

	        _FD.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
             _FD.filterChanged = false;
             
	        var flag = _FD.core.refreshReports();
	                
	        if(flag) {
	        	HelpdeskReports.locals.saved_report_used = true;
	        	if(refresh){ 
		        	_FD.applySpecificReportActions(index);
		        }
	            _this.controls.hideSaveOptions();
	            _this.cacheLastAppliedReport(id);
	            if(index != -1) {
	                _this.controls.showDeleteAndEditOptions();
	                _this.controls.showScheduleOptions(false);

	                if(is_preset_selected){
	            		_this.controls.showScheduleOptions(false);
		            } else {
		            	_this.controls.hideScheduleOptions();
		            }

	            } else{
	            	_this.controls.hideDeleteAndEditOptions();
	            	_this.controls.showScheduleOptions(true);
	            }
	            var result = Helpkit.ScheduleUtil.isScheduled(
	            		_this.last_applied_saved_report_index,
	            		_this.default_report_is_scheduled,
	            		_this.default_index,
	            		HelpdeskReports.locals.report_filter_data
	            		);
	            if(result.is_scheduled){
                	Helpkit.ScheduleUtil.displayScheduleStatus(true,result.tooltip_title);
                } else{
                	Helpkit.ScheduleUtil.displayScheduleStatus(false);
                }
	            if(invalid_params_found) {
	            	//update the filter , removing the invalid params done in above loop
	            	_FD.updateSavedReport(false);
            	}else{
		        	 jQuery('#loading-box').hide();
		        }
	        }
	    },
	    applySpecificReportActions : function(index) {

	    	var report_type = HelpdeskReports.locals.report_type;
	    	var hash = HelpdeskReports.locals.report_filter_data;

	    	if(index == -1) {
	    		jQuery("[data-action='reports-submit']").click();
	    		return;
	    	}
	    	var hash = hash[index].report_filter.data_hash;

	    	if(report_type == 'glance') {
	    		if(hash != undefined ) {
	    			HelpdeskReports.locals.active_metric = hash.active_metric;
	    			//trigger_event("set_active_view.helpdesk_reports",{});	
	    			jQuery("[data-action='reports-submit']").click();
	    		}
	    	} else if(report_type == 'ticket_volume') {
	    		HelpdeskReports.locals.trend = hash.trend;
	    		jQuery("[data-action='reports-submit']").click();
    			if(hash != undefined ){
    				//jQuery("[data-trend='trend-type'][data-format='" + extras.trend + "']").trigger('click');
    			}
	    	} else {
	    		jQuery("[data-action='reports-submit']").click();
	    	}
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
	    updateSavedReport : function(isUpdateTitle) {
	        var _this = this;
	        var params = {};
	        params.data_hash = {};
	        var locals = HelpdeskReports.locals;
	        var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));

	        if(current_selected_index == -1) {
	        	current_selected_index = _this.default_index;
	        	params.data_hash.default_report_is_scheduled = true;
	        }

		    params.data_hash.select_hash = locals.select_hash;
	        _FD.attachExtraParamsPerReport(params.data_hash);

	        params.data_hash.report_filters = locals.local_hash;
	        
	        if(is_scheduled_op){
	        	params.filter_name = locals.report_filter_data[current_selected_index].report_filter.filter_name;
	        	params.data_hash.schedule_config = Helpkit.ScheduleUtil.getScheduleParams();
	        	params.data_hash.date = locals.report_filter_data[current_selected_index].report_filter.data_hash.date;
	        } else {
	        	if(isUpdateTitle) {
		        	params.filter_name = _this.escapeString(jQuery("#filter_name_save").val());
		        	params.data_hash.schedule_config = locals.report_filter_data[current_selected_index].report_filter.data_hash.schedule_config;
		        	params.data_hash.date = locals.report_filter_data[current_selected_index].report_filter.data_hash.date;
		        } else {
		        	params.filter_name = locals.report_filter_data[current_selected_index].report_filter.filter_name;
		        	params.data_hash.schedule_config = locals.report_filter_data[current_selected_index].report_filter.data_hash.schedule_config;
		        	params.data_hash.date = {};
		        	
		        	if(locals.presetRangesSelected) {
			        	params.data_hash.date.date_range = _FD.core.dateRangeDiff(locals.date_range);
			        	params.data_hash.date.presetRange = true;
			        	params.data_hash.date.period = locals.presetRangesPeriod;
			        } else {
			        	params.data_hash.date.date_range = locals.date_range;
			        	params.data_hash.date.presetRange = false;
			        }
		        }
	        }
	        
	        params.id = locals.report_filter_data[current_selected_index].report_filter.id;
	        if(locals.report_type == "glance" && locals.active_custom_field){
	            params["active_custom_field"] = locals.active_custom_field;
	        }
	        var opts = {
	            url: _FD.core.CONST.base_url + locals.report_type + _FD.CONST.update_report,
	            type: 'POST',
	            contentType: 'application/json',
	            data: Browser.stringify(params),
	            timeout: _FD.core.timeouts.main_request,
	            success: function (resp) {
	                    //update one array -> report_filter_data
	                    var obj = {};
	                    obj.report_filter = {};
	                    obj.report_filter.filter_name = resp.filter_name;
	                    obj.report_filter.data_hash = resp.data;
	                    obj.report_filter.id = resp.id;
	                    locals.report_filter_data[current_selected_index] = obj;

	                    if(_FD.last_applied_saved_report_index != -1) {

			                    _FD.filterChanged = false;
			                    _FD.controls.hideSaveOptions();
			                    _FD.controls.showDeleteAndEditOptions();
			                    if(resp.data.date.presetRange) {
			                    	_FD.controls.showScheduleOptions(false);	
			                    } else{
			                    	_FD.controls.hideScheduleOptions(false);
			                    }

			                    _FD.populateSavedReports(current_selected_index);
			                    _FD.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + current_selected_index +"]"));

			                    //Update the used names array
			                    var index = _FD.saved_report_names.indexOf(params.filter_name);
			                    if (index > -1) {
								    _FD.saved_report_names[index] = resp.filter_name.toLowerCase();
								}
	                    } 
	                    //if this report was scheduled show it

	                    if(resp.data.schedule_config.enabled){
	                    	Helpkit.ScheduleUtil.displayScheduleStatus(true,Helpkit.ScheduleUtil.getTooltipMessage(resp.data.schedule_config));
	                    } else{
	                    	Helpkit.ScheduleUtil.displayScheduleStatus(false);
	                    }
	                    
	                    //Show successfully updated message
	                    HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.updated_message'));
	            },
	            error: function (xhr,exception) {
	            	if(xhr.status == 422){
	            		HelpdeskReports.CoreUtil.showResponseMessage(JSON.parse(xhr.responseText)['errors']);
	            	} else{
	            		HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.update_failed_message'));
	            	}
	            }
	        };
	        _FD.core.makeAjaxRequest(opts);
	    },
	    flushAppliedFilters : function() {
	            
	            var _this = this;
	            var hash = HelpdeskReports.locals.report_filter_data;

	            /*
	            //Clear the values populated by previous saved report
	            if(_this.last_applied_saved_report_index != -1) {
	                
	                var last_index = _this.last_applied_saved_report_index;
	                last_hash = hash[last_index].report_filter;

	                jQuery.each(last_hash.data_hash.report_filters, function(index, val) {
	                         var filter_row = val;
	                         var condition = filter_row.condition;
	                         var current_condition_select2_div = jQuery('#div_ff_' + condition);
	                         //If populated field was a default field, clear it,otherwise remove it
	                         if(jQuery.inArray(condition,_this.default_available_filter) != -1){
	                            jQuery('#div_ff_' + condition + ' select').select2('val',"");
	                         } else{
	                            
	                             if (current_condition_select2_div.attr('data-type') && current_condition_select2_div.attr('data-type') === "filter-field") {
	                                _this.actions.removeField(current_condition_select2_div);
	                             }   
	                         }
	                          
	                });
	            }
	            */
	            jQuery("#active-report-filters div.ff_item").map(function() {
	                var condition = this.getAttribute("condition");
	                var container = this.getAttribute("container");
	                var operator  = this.getAttribute("operator");
	                //Removing fields with no values in filters by triggering click.(only for non default fields)
	                if(_FD.core.default_available_filter.indexOf(condition) < 0){
	                    var active = jQuery('#div_ff_' + condition);
	                    if (active.attr('data-type') && active.attr('data-type') === "filter-field") {
	                        _FD.core.actions.removeField(active);
	                    }    
	                } 
	                else{
	                    var active = jQuery('#' + condition);
	                    active.select2('val','');
	                }
	                
	            });
	    },
	    /*
	     * This function will clear the all the filters and re apply the filters of selected saved report
	     */
	    discardChangesMadeToFilter : function() { 
	    	HelpdeskReports.locals.active_custom_field = HelpdeskReports.locals.default_custom_field;
	        this.applySavedReport(this.last_applied_saved_report_index,true);
	        this.controls.hideSaveOptions(); 
	    },
	    deleteSavedReport : function() {

	        var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
	        var _this = this;
	        
	        _FD.flushAppliedFilters();

	        var opts = {
	            url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + _FD.CONST.delete_report,
	            type: 'POST',
	            dataType : 'text',
	            data: {
	                id : HelpdeskReports.locals.report_filter_data[current_selected_index].report_filter.id 
	            },
	            timeout: _FD.core.timeouts.main_request,
	            success: function (resp) {

	                    //update -> report_filter_data & menu
	                    HelpdeskReports.locals.report_filter_data.splice(current_selected_index,1);
	                    //HelpdeskReports.locals.report_filter_data[current_selected_index] = {};
	                    //jQuery(".reports-menu li a[data-index=" + current_selected_index +"]").remove();
	                    _FD.populateSavedReports(-1);
	                    _FD.applySavedReport(-1,true);

	                    if(HelpdeskReports.locals.report_filter_data.length == 0){
	                    	jQuery(".saved_reports_list .seperator").addClass('hidden');
	                    } else{
	                    	jQuery(".saved_reports_list .seperator").removeClass('hidden');
	                    }
	                    //Show successfully deleted message
	                    HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.deleted_message'));
	            },
	            error: function (data) {
	                HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.deleted_failed_message'));
	            }
	        };
	        _FD.core.makeAjaxRequest(opts);
	    },
	    attachExtraParamsPerReport : function(params) {
	    	var report_type = HelpdeskReports.locals.report_type;
	    	if( report_type == 'glance' ){
	    		params.active_metric = HelpdeskReports.locals.active_metric;
	    	} else if( report_type == 'ticket_volume') {
	    		params.trend = HelpdeskReports.locals.trend;
	    	} else if( report_type == 'performance_distribution') {
	    		params.resolution_trend = HelpdeskReports.locals.resolution_trend;
	    		params.response_trend = HelpdeskReports.locals.response_trend;
	    	}
	    },
	    checkNameAvailability : function(name) {
	    	if(is_save_op) {
	    		if(!_FD.filterChanged && _FD.last_applied_saved_report_index == -1){
	    			return true;
		    	}

		    	if(jQuery.inArray(name.toLowerCase(),_FD.saved_report_names) != -1){
		    		return false;
		    	}	
	    	} else {
	    		if(_FD.last_applied_saved_report_index != -1) {
	    			var old_name = HelpdeskReports.locals.report_filter_data[_FD.last_applied_saved_report_index].report_filter.filter_name;
			    	var temp = _FD.saved_report_names.slice();
			    	var index = temp.indexOf(old_name.toLowerCase());
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
	    checkValidityOfSavedParams : function(condition,value,source) {

	    	var options_hash = HelpdeskReports.locals.report_options_hash;
	    	var assert = false;

	    	if(jQuery.inArray(condition,_FD.core.filter_remote) != -1) {
	    		assert = _FD.invokeElasticSearch(condition,value,source);
	    	} else {
	    		var condition_options = options_hash[condition];
	    		if(condition_options != undefined && condition_options.hasOwnProperty(value)) {
	    			assert = true;
	    		} else {
	    			assert = false;
	    		}
	    	}
	    	return assert;
	    },
	    invokeElasticSearch : function(condition,value,source) {
	        
	        var _this = this;
	        var is_result_found = false;

	        var search_term;
	        var found_idx;
	        //loop source object to get the search term for passed value
	        jQuery.each(source,function(idx,option) { 
	        	if(option.id == value){
	        		search_term = option.text;
	        		found_idx = idx;
	        		return false;
	        	}
	        });

            var opts = {
                url: "/search/autocomplete/" + _FD.core.filter_remote_url[condition] + "?q=" + search_term,
                type: 'GET',
                async : false,
                dataType: 'json',
                timeout: _FD.core.timeouts.ticket_list,
                success: function (data) {
                  	if(data.results != undefined && data.results.length > 0) {
                  		is_result_found = true;
                  	} else{
                  		source.splice(found_idx,1);
                  	}
                },
                error: function (data) {
                    console.log('Search validation of elastic params failed');
                }
            }
            _FD.core.makeAjaxRequest(opts);

	 		return is_result_found;       
	    },
    	cacheLastAppliedReport : function(index){
			 if (typeof (Storage) !== "undefined") {
	            //Storing the index of visited report to retain it.
	            window.localStorage.setItem(HelpdeskReports.locals.report_type,index);
	         }    		
    	},
    	applyLastCachedReport : function(){
	        if (typeof (Storage) !== "undefined" && localStorage.getItem(HelpdeskReports.locals.report_type) !== null) {
                var index = JSON.parse(localStorage.getItem(HelpdeskReports.locals.report_type));
                _FD.applySavedReport(_FD.getDataIndex(index),false);
                _FD.filterChanged = false
            } else {
                _FD.applySavedReport(-1,false);
            }
	    },
	    escapeString : function(name) {
    		//return name != undefined ? escapeHtml(name).replace(/'/g, '&apos;') : name;
    		return name;
    	},
    	hideTwipsy : function(container){
    		var twipsy = jQuery("#" + container + " i ").data('twipsy');
    		if(twipsy != undefined) {
    			twipsy.hide();
    		}
    	},
    	/* Used for identifying index from cached id */
    	getDataIndex : function(id){
    		var hash = HelpdeskReports.locals.report_filter_data;
    		var index = -1;
    		if(hash != undefined) {
    			jQuery.each(hash,function(idx,obj){
    				if(obj.report_filter.id == id){
    					index = idx;
    				}	
    			});	
    		}
    		return index;
    	},
    	init: function (index) {
			if(!this.initialized){
		        _FD.core = HelpdeskReports.CoreUtil;
		        _FD.constants = jQuery.extend({}, HelpdeskReports.Constants.Glance);
		        _FD.bindEvents();
		        _FD.populateSavedReports(index);
		        this.initialized = true;
		    }
	    }
	};
	return _FD;
})();


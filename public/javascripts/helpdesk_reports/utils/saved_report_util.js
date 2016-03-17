HelpdeskReports.SavedReportUtil = HelpdeskReports.SavedReportUtil || {};

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
		    bindEvents : function() {

		    	jQuery(document).on('click',"#save_filter",function(){
		    		jQuery("#report-dialog-save .unavailable_field").addClass('hide');
		     	    jQuery("#report-dialog-save .missing_field").addClass('hide');
		    		//Set the value of input field
		    		var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
		    		current_title = 'Copy of ' + current_title;
		    		jQuery("#filter_name_save").val(current_title);
		    	});

		    	jQuery(document).on('click',"#edit_filter",function(){
		    		jQuery("#report-dialog-edit .unavailable_field").addClass('hide');
		     	    jQuery("#report-dialog-edit .missing_field").addClass('hide');
		    		//Set the value of input field
		    		var current_title = jQuery(".reports-menu li.active a").attr('data-original-title');
		    		jQuery("#filter_name_edit").val(current_title);
		    	});

		    	//Saved Reports
		        jQuery(document).on('click',"#report-dialog-save-submit",function() {  

		        	var field_val = jQuery("#filter_name_save").val().trim();   
		         	if(field_val == "") {
		            	jQuery("#report-dialog-save .missing_field").removeClass('hide');
		            	jQuery("#report-dialog-save .unavailable_field").addClass('hide');
		          	} else {
		          		jQuery("#report-dialog-save .missing_field").addClass('hide');
		          		if(_FD.checkNameAvailability(field_val)) {
		          			jQuery("#report-dialog-save .unavailable_field").addClass('hide');
			         	    _FD.saveReport();
			               jQuery("#report-dialog-save-cancel").click();
		          		} else{
		          		  jQuery("#report-dialog-save .unavailable_field").removeClass('hide');
		          		} 
		          	}
		        });

		        jQuery(document).on('click',"#report-dialog-edit-submit",function() {  

		        	var field_val = jQuery("#filter_name_edit").val().trim();   
		         	if( field_val == "") {
		            	jQuery("#report-dialog-edit .missing_field").removeClass('hide');
		            	jQuery("#report-dialog-edit .unavailable_field").addClass('hide');
		          	} else {
		          		jQuery("#report-dialog-edit .missing_field").addClass('hide');
		          		if(_FD.checkNameAvailability(field_val)) {
		          			jQuery("#report-dialog-edit .unavailable_field").addClass('hide');
			         	    _FD.updateSavedReport(true);
			               jQuery("#report-dialog-edit-cancel").click();
		          		} else{
		          		  jQuery("#report-dialog-edit .unavailable_field").removeClass('hide');
		          		} 
		          	}
		        });

		        jQuery(document).on('click',"#report-dialog-delete-submit",function() {  
		        		 _FD.deleteSavedReport();
		        		jQuery("#report-dialog-delete-cancel").click();
		        });

		        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="update-saved-report"]', function () {
		            _FD.updateSavedReport(false);
		        });

		        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="discard-changes"]', function () {
		            _FD.discardChangesMadeToFilter();
		        });

		        jQuery('#reports_wrapper').on('click.helpdesk_reports', '[data-action="select-saved-report"]', function () {
		           var index = jQuery(this).attr('data-index');
		           jQuery('#loading-box').show();
		           setTimeout(function(){
		           		_FD.applySavedReport(index,true); 
		           },1000);
		           
		        });
		        jQuery('#reports_wrapper').on('change', '[data-type="filter-field"]', function () { 
		            _FD.filterChanged = true;
		        });
		        jQuery(document).on("report_refreshed",function(ev,data){
		        	if(_FD.filterChanged) {
		        		 _FD.controls.hideDeleteAndEditOptions();
		           		 _FD.controls.showSaveOptions(_FD.last_applied_saved_report_index);	
		        	}
		        });
		        jQuery(document).on("filter_changed",function(ev,data){
		        	_FD.filterChanged = true;
		        });
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
		        } else {
		        	params.data_hash.date.date_range = locals.date_range;
		        	params.data_hash.date.presetRange = false;
		        }
		       
		       	params.data_hash.select_hash = locals.select_hash;
		        params.data_hash.report_filters = locals.local_hash.splice(0);
		        //Add a empty schedule config
		        params.data_hash.schedule_config = {
		        	enabled : false
		        };
		        params.filter_name = _this.escapeString(jQuery("#filter_name_save").val());
		        //update the edit popup with this name
		        //jQuery("#filter_name_edit").val(params.filter_name);

		        _FD.attachExtraParamsPerReport(params.data_hash);

		        var opts = {
		            url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + _FD.CONST.save_report,
		            type: 'POST',
		            contentType: 'application/json',
		            data: Browser.stringify(params),
		            timeout: _FD.core.timeouts.main_request,
		            success: function (resp) {

		                if(resp.status == "ok") {
		                    //update report_filter_data 
		                    var obj = {};
		                    obj.report_filter = {};
		                    obj.report_filter.filter_name = resp.filter_name;
		                    obj.report_filter.id = resp.id;
		                    //bad response object structure
		                    obj.report_filter.data_hash = resp.data;
		                    HelpdeskReports.locals.report_filter_data.push(obj);

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
		                    _FD.controls.hideSaveOptions();
		                    _FD.filterChanged = false;

		                    if(HelpdeskReports.locals.report_filter_data.length > 0){
		                    	jQuery(".saved_reports_list .seperator").removeClass('hidden');
		                    }
		                     //Show successfully saved message
		                    HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.saved_message'));
		                    _this.cacheLastAppliedReport(resp.id);
		                }
		            },
		            error: function (xhr,exception) {
		            	if(xhr.status == 422){
		            		HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.limit_exceeded_message',{count: xhr.responseText}));
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
		                option.id = index; //id is populated in front end to identify ith saved report filter.
		                option.text = report_filter.filter_name;
		                _FD.saved_report_names.push(report_filter.filter_name.toLowerCase());
		                rows.push(option);
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
		            if(_FD.checkNameAvailability(report_name)) {
		            	_FD.saved_report_names.push(report_name);
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
		        var id = -1;
		        _FD.flushAppliedFilters();
		        _FD.last_applied_saved_report_index = index;

		        if(index != -1) {
		            var filter_hash = hash[index].report_filter;
		            id = filter_hash.id;
		            var date_hash = filter_hash.data_hash.date;
		            var daterange;//_FD.core.convertDateDiffToDate(date_hash.date_range);
		            //Set the date range from saved range
		            if(date_hash.presetRange) {
		            	daterange = _FD.core.convertDateDiffToDate(date_hash.date_range);
		            } else {
		            	daterange = date_hash.date_range;
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
		           
		        } else{
		        	var default_date_range = _FD.core.convertDateDiffToDate(29);
		        	jQuery('#date_range').val(default_date_range);
		        }

		        _FD.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));

		        var flag = _FD.core.refreshReports();
		                
		        if(flag) {
		        	if(refresh){ 
		        		_FD.applySpecificReportActions(index);
		        	}
		        	_this.cacheLastAppliedReport(id);
		            _this.controls.hideSaveOptions();
		            
		            if(index != -1) {
		                _this.controls.showDeleteAndEditOptions();
		            } else{
		            	_this.controls.hideDeleteAndEditOptions();
		            }
		            if(invalid_params_found) {
		            	//update the filter , removing the invalid params done in above loop
		            	_FD.updateSavedReport(false);
	            	}
		        } else{
		        	 jQuery('#loading-box').hide();
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
		    		_FD.core.resetAndGenerate();
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
		        }
		    },
		    updateSavedReport : function(isUpdateTitle) {
		        var _this = this;
		        var params = {};
		        params.data_hash = {};
		        var locals = HelpdeskReports.locals;
		        var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));

		        params.data_hash.date = {};
		        if(locals.presetRangesSelected) {
		        	params.data_hash.date.date_range = _FD.core.dateRangeDiff(locals.date_range);
		        	params.data_hash.date.presetRange = true;
		        } else {
		        	params.data_hash.date.date_range = locals.date_range;
		        	params.data_hash.date.presetRange = false;
		        }
			    params.data_hash.select_hash = locals.select_hash;
		        _FD.attachExtraParamsPerReport(params.data_hash);
		        params.data_hash.report_filters = jQuery.extend([],locals.local_hash);
		        params.data_hash.schedule_config = {
		        	enabled : false
		        };
		        if(isUpdateTitle) {
		        	params.filter_name = _this.escapeString(jQuery("#filter_name_edit").val());
		        } else {
		        	params.filter_name = HelpdeskReports.locals.report_filter_data[current_selected_index].report_filter.filter_name;
		        }
		        
		        params.id = HelpdeskReports.locals.report_filter_data[current_selected_index].report_filter.id;

		        var opts = {
		            url: _FD.core.CONST.base_url + HelpdeskReports.locals.report_type + _FD.CONST.update_report,
		            type: 'POST',
		            contentType: 'application/json',
		            data: Browser.stringify(params),
		            timeout: _FD.core.timeouts.main_request,
		            success: function (resp) {
		                if(resp.status == "ok") {
		                    //update one array -> report_filter_data
		                    var obj = {};
		                    obj.report_filter = {};
		                    obj.report_filter.filter_name = resp.filter_name;
		                    obj.report_filter.data_hash = resp.data;
		                    obj.report_filter.id = resp.id;
		                    HelpdeskReports.locals.report_filter_data[current_selected_index] = obj;

		                    _FD.filterChanged = false
		                    _FD.controls.hideSaveOptions();
		                    _FD.controls.showDeleteAndEditOptions();

		                    _FD.populateSavedReports(current_selected_index);
		                    _FD.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + current_selected_index +"]"));

		                    //Update the used names array
		                    var index = _FD.saved_report_names.indexOf(params.filter_name);
		                    if (index > -1) {
							    _FD.saved_report_names[index] = resp.filter_name.toLowerCase();
							}
		                    //Show successfully updated message
		                    HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.updated_message'));
		                }
		            },
		            error: function (data) {
		                console.log('Update Error');
		                HelpdeskReports.CoreUtil.showResponseMessage(I18n.t('helpdesk_reports.saved_report.update_failed_message'));
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
		    	if(jQuery.inArray(name.toLowerCase(),_FD.saved_report_names) != -1){
		    		return false;
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
	    		return name != undefined ? escapeHtml(name).replace(/'/g, '&apos;') : name;
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


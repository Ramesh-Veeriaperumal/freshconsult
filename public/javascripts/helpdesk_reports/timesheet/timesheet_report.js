
jQuery(document).ready(function() {

    jQuery("#exportLink").click(function(){
            var opts = {
                    url : '/timesheet_reports/configure_export',
                    type: 'GET',
                    dataType: 'json',
                    contentType: 'application/json',
                    success: function (data) {
                      var tmpl = JST["helpdesk_reports/templates/export_fields_tmpl"]({
                            'data': data
                        });
                        jQuery("#ticket_fields").removeClass('sloading loading-small');
                        jQuery('#ticket_fields').html(tmpl);
                        bindExportFieldEvents();
                    },
                    error: function (data) {
                        _this.appendExportError();
                    }
                };
                jQuery.ajax(opts);
    });

    function bindExportFieldEvents() {

        var export_fields = jQuery("#ticket_fields input[type='checkbox']");
        jQuery('#toggle_checks').on('change', function () {
                jQuery(export_fields).prop('checked', jQuery(this).is(":checked"));
        });

        //For toggling select all/none checkbox when toggling fields -->
        jQuery(export_fields).on('change', function () {
            var count = 0;
            jQuery(export_fields).each(function(i,ele){ if(ele.checked) count++; });
            jQuery('#toggle_checks').prop('checked', (jQuery(export_fields).length == count));
        });

        jQuery("#export_submit").click(function () {  
            if (jQuery('#ticket_fields :checked').length == 0) {
                jQuery('#err_no_fields_selected').removeClass('hide');
                return false;
            } else {
                jQuery('#err_no_fields_selected').addClass('hide');
                jQuery("#export_submit").prop('disabled', 'disabled').addClass("disabled").html("Exporting...");
            }
        });
    }

    jQuery(document).on("presetRangesSelected", function(event,status) {
        Helpkit.presetRangesSelected = status;
    });
    savedReportUtil.init();
});

//Analytics
    
function recordAnalytics(){

    jQuery(document).on("script_loaded", function (ev, data) {
         App.Report.Metrics.push_event("TimeSheet Report Visited", {});
    });
    //Download link
    jQuery(".proxy-generate-pdf").click(function(ev) {
        App.Report.Metrics.push_event("TimeSheet PDF Downloaded", {});
    });
    jQuery("#export_as_csv").click(function(ev) {
        App.Report.Metrics.push_event("TimeSheet CSV Exported", {});
    });

    jQuery("#submit").click(function(ev) {

        var date_range = jQuery("#date_range").val().split('-');
        var diff = -1;
        var event_prop = {
          Date: jQuery("#date_range").val()
        };

        if (date_range.length == 2){
          diff = (new Date().setHours(0,0,0,0) - Date.parse(date_range[1])) / (36e5 * 24);  
        } else{
           diff = (new Date().setHours(0,0,0,0) - Date.parse(date_range[0])) / (36e5 * 24);
        }
        
        if(diff == 0) {
          event_prop.today_used_in_range = true;
        }
        if(diff == 1) {
          event_prop.yesterday_used_in_range = true;
        }
        App.Report.Metrics.push_event("TimeSheet Report Generated", event_prop);
    });
}

var savedReportUtil = (function() {
        
    var _FD = {
        last_applied_saved_report_index : -1,
        CONST: {
            base_url : "/timesheet_reports",
            save_report   : "/save_reports_filter",
            delete_report : "/delete_reports_filter",
            update_report : "/update_reports_filter"
        },
        save_util : Helpkit.commonSavedReportUtil,
        remote_filters : ["customers_filter"],
        filters : [ "customers_filter","user_id" ,"billable","products_id","group_id","ticket_type","priority","group_by_field"],
        filterChanged : false,
        bindSavedReportEvents : function() {
            var _this = this;
            jQuery(document).on('change', '#customers_filter,.filter_item,.ff_item', function () { 
                 _this.filterChanged = true;
            });

            jQuery(document).on("save.report",function() {
              _this.saveReport();
            });
            jQuery(document).on("delete.report",function() { 
              _this.deleteSavedReport();
            })
            jQuery(document).on("edit.report",function(ev,data) {
              _this.updateSavedReport(data.isNameUpdate);
            });
            jQuery(document).on("discard_changes.report",function() {
              _this.discardChanges();
            });
            jQuery(document).on("apply.report",function(ev,data) {
              jQuery('[data-action="pop-report-type-menu"]').trigger('click');
              _this.applySavedReport(data.index);
            });
            jQuery(document).on("filter_changed",function(ev,data){
                _this.filterChanged = true;
            });
            jQuery(document).on("report_refreshed",function(ev,data){
                if(_this.filterChanged) {
                     _this.save_util.controls.hideDeleteAndEditOptions();
                     _this.save_util.controls.showSaveOptions(_this.last_applied_saved_report_index); 
                } else{
                  var index = parseInt(jQuery('.active [data-action="select-saved-report"]').attr('data-index'));
                  if(index != -1) {
                      _this.save_util.controls.showDeleteAndEditOptions();
                  }
                }
            });
        },
        saveReport : function() {
              var _this = this;
              var opts = {
                  url: _this.CONST.base_url + _this.CONST.save_report,
                  callbacks : { 
                     success: function () {
                          //update the last applied filter
                          _this.last_applied_saved_report_index = this.new_id;
                          _this.filterChanged = false;
                     },error: function () {}
                  },
                  params : _this.getParams()
                 };
                  
              _this.save_util.saveHelper(opts);
        },
        getParams : function() {
          var params = {};
          var form_data = [];//jQuery('#report_filters').serializeArray();
          var _this = this;

          params.data_hash = {};

          jQuery.each(this.filters,function(idx,condition) {
                var val = jQuery('#' + condition).select2('val');
                if(val != ""){
                    var opt = {
                        name : condition,
                        value : val.toString()
                    }
                    if(condition == "customers_filter") {
                      var source = jQuery('#' + condition).data('select2').opts.data;
                      opt.source = source;
                      opt.name = "customer_id";
                    }
                    form_data.push(opt);
                }
           });

          var dateRange = jQuery("#date_range").val();

          params.data_hash.date = {};
          if(Helpkit.presetRangesSelected) {
               params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
               params.data_hash.date.presetRange = true;
          } else {
               params.data_hash.date.date_range = dateRange;
               params.data_hash.date.presetRange = false;
          }                   
          params.data_hash.report_filters = form_data;
          params.data_hash.select_hash = Helpkit.select_hash;
          return params;
        },
        updateSavedReport : function(isUpdateTitle) {
              var _this = this;
              
              var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
              var params = _this.getParams();

              if(isUpdateTitle) {
                params.filter_name = _this.save_util.escapeString(jQuery("#filter_name_edit").val());
              } else {
                params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
              }
              params.id = Helpkit.report_filter_data[current_selected_index].report_filter.id;

              var opts = {
                  current_selected_index : current_selected_index,
                  url: _this.CONST.base_url + _this.CONST.update_report,
                  callbacks : {
                     success: function () {
                      _this.filterChanged = false
                     },
                     error: function (data) {
                      }
                  },
                  params : params
              };
              _this.save_util.updateHelper(opts);
        },
        deleteSavedReport : function() {
              var _this = this;
              var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
              _this.flushAppliedFilters();

              var opts = {
                  current_selected_index : current_selected_index,
                  url: _this.CONST.base_url + _this.CONST.delete_report,
                  callbacks : {
                    success: function (resp) {
                      _this.applySavedReport(-1);
                    },
                    error: function (data){}
                  }
              };
              _this.save_util.deleteHelper(opts);
        },
        discardChanges : function() {
          this.applySavedReport(this.last_applied_saved_report_index);
          this.save_util.controls.hideSaveOptions(); 
        },
        applySavedReport : function(index) {

            var hash = Helpkit.report_filter_data;
            var _this = this;
            var invalid_params_found = false;

            _this.flushAppliedFilters();
            _this.last_applied_saved_report_index = index;
            var id = -1;

            if(index != -1) {

                var filter_hash = hash[index].report_filter;
                id = filter_hash.id;
                //Set the date range from saved range
                var date_hash = filter_hash.data_hash.date;
                var daterange;
                //Set the date range from saved range
                if(date_hash.presetRange) {
                  daterange = _this.save_util.convertDateDiffToDate(date_hash.date_range);
                } else {
                  daterange = date_hash.date_range;
                }
                jQuery('#date_range').val(daterange);
                
                if(filter_hash.data_hash.report_filters != null) {
                   
                    jQuery.each(filter_hash.data_hash.report_filters, function(index, filter_row) {
                      var condition = filter_row.name;

                      if(condition == "group_by"){
                          //jQuery("#group_by_field").select2('val',filter_row.value);
                      } else if(condition == "customer_id") {
                          _this._constructElasticSearchField("customers_filter",filter_row.source);
                          jQuery('#customers_filter').select2('val',filter_row.value.split(','));
                      } else {
                          //populate the value
                          var is_saved_param_valid = _this.checkValidityOfSavedParams(condition,filter_row.value);
                          
                          if (is_saved_param_valid) {
                             jQuery('#'+ condition).select2('val',filter_row.value.split(','));
                          } else {
                            filter_hash.data_hash.report_filters.splice(index,1);
                            invalid_params_found = true;
                          }
                      }
                      
                  });
                }
                
            } else {
              var default_date_range = _this.save_util.convertDateDiffToDate(29);
              jQuery('#date_range').val(default_date_range);
            }

            _this.save_util.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
            _this.filterChanged = false;
            jQuery("#submit").trigger('click');
            _this.save_util.cacheLastAppliedReport(id);
            
            _this.save_util.controls.hideSaveOptions();
            if(index != -1) {
                _this.save_util.controls.showDeleteAndEditOptions();
            } else{
              _this.save_util.controls.hideDeleteAndEditOptions();
            }
            if(invalid_params_found) {
              //update the filter , removing the invalid params done in above loop
              _this.updateSavedReport(false);
            }
            
        },
        checkValidityOfSavedParams : function() {
            return true;
        },
        flushAppliedFilters : function() {
           jQuery.each(this.filters,function(idx,condition) {
                jQuery('#' + condition).select2('val','');
           });
        },
        _constructElasticSearchField : function(condition,initData){

           jQuery('#' + condition).select2('destroy');

           var config = {};
           config.ajax = {
              url: "/search/autocomplete/companies" ,
              dataType: 'json',
              delay: 250,
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
                                text: item.value
                              });    
                        });
                        return {
                          results: results 
                        };
              },
              cache: true
            };
            config.multiple = true ;
            config.minimumInputLength = 2 ;
            config.initSelection = function (element, callback) {
                    if(initData != undefined){
                       callback(initData);  
                    }
            };
            jQuery("#" + condition).select2(config);
        },
        init : function(){
           _FD.bindSavedReportEvents();
           _FD.save_util.init();
           _FD.save_util.applyLastCachedReport();
        }
    }
    return _FD;
})();

 function setFilterText() {

      var filters_name = [ "customers_filter","user_id" ,"billable","products_id","group_id","ticket_type","priority"];

      var labels = [
        I18n.t('helpdesk.time_sheets.customer'),
        I18n.t('helpdesk.time_sheets.agent'),
        I18n.t('helpdesk.time_sheets.billing_type'),
        I18n.t('helpdesk.time_sheets.group'),
        I18n.t('helpdesk.time_sheets.product'),
        I18n.t('helpdesk.time_sheets.ticket_type'),
        I18n.t('helpdesk.time_sheets.ticket_priority')
      ]
      
      var display = [];

      jQuery.each(filters_name,function(idx,name){
          var selected_options = [];
          selected_options = jQuery('#' + name).select2('data');
          var txt = "";
          if(selected_options && selected_options.length){
            jQuery.each(selected_options,function(i,option){
                if(name != "customers_filter") {
                  txt += option.text; 
                } else {
                  txt += option.value;
                }
                
                if(i != selected_options.length -1){
                  txt += ",";
                }
            });
            var data = {
              label : labels[idx],
              text : txt
            }
            display.push(data);
          }

      });
      var tmpl = JST["helpdesk_reports/templates/filter_data_timesheet_tmpl"]({ 
            data : display 
        });
      jQuery("#filter_text_others").html(tmpl);
      Helpkit.select_hash = display;
    }

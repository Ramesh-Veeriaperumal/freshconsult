
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

    jQuery(document).on("presetRangesSelected", function(event,data) {
        Helpkit.presetRangesSelected = data.status;
        Helpkit.presetRangesPeriod = data.period;
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

            jQuery(document).on('change', '#customers_filter,.filter_item,.ff_item', function (ev) { 
                 if(ev.target && ev.target.id != "group_by_field"){
                    _this.filterChanged = true; 
                    _this.save_util.filterChanged = true;
                    _this.setFlag('false');
                 }
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
                _this.save_util.filterChanged = true;
                _this.setFlag('false');
            });
            jQuery(document).on("report_refreshed",function(ev,data){
                if(_this.filterChanged) {
                     _this.save_util.controls.hideDeleteAndEditOptions();
                     _this.save_util.controls.hideScheduleOptions();
                     _this.save_util.controls.showSaveOptions(_this.last_applied_saved_report_index); 
                } else{
                  var index = parseInt(jQuery('.active [data-action="select-saved-report"]').attr('data-index'));
                  if(index != -1) {
                      _this.save_util.controls.showDeleteAndEditOptions();
                      if(is_preset_selected){
                        _this.save_util.controls.showScheduleOptions(false);

                        var result = Helpkit.ScheduleUtil.isScheduled(
                          _this.last_applied_saved_report_index,
                          _this.save_util.default_report_is_scheduled,
                          _this.save_util.default_index,
                          Helpkit.report_filter_data
                          );
                        if(result.is_scheduled){
                          Helpkit.ScheduleUtil.displayScheduleStatus(true,result.tooltip_title);
                        } else{
                          Helpkit.ScheduleUtil.displayScheduleStatus(false);
                        }
                      } else{
                        _this.save_util.controls.hideScheduleOptions();
                      }
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
                          _this.save_util.filterChanged = false;
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
                    }
                    form_data.push(opt);
                }
           });

          var dateRange = jQuery("#date_range").val();

          params.data_hash.date = {};
          if(Helpkit.presetRangesSelected) {
               params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
               params.data_hash.date.presetRange = true;
               params.data_hash.date.period = Helpkit.presetRangesPeriod;
          } else {
               params.data_hash.date.date_range = dateRange;
               params.data_hash.date.presetRange = false;
          }                   
          params.data_hash.report_filters = form_data;
          params.data_hash.select_hash = Helpkit.select_hash;
          if(_this.last_applied_saved_report_index == -1 && !_this.filterChanged) {
            params.data_hash.default_report_is_scheduled = true;
          }
          return params;
        },
        updateSavedReport : function(isUpdateTitle) {
              var _this = this;
              
              var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
              var params = _this.getParams();
              var dateRange = jQuery("#date_range").val();

              if(current_selected_index == -1) {
                 current_selected_index = _this.save_util.default_index;
                 params.data_hash.default_report_is_scheduled = true;
              }

              if(is_scheduled_op){
                    params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
                    params.data_hash.schedule_config = Helpkit.ScheduleUtil.getScheduleParams();
                    params.data_hash.date = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.date;
              } else {
                
                if(isUpdateTitle) {
                    params.filter_name = _this.save_util.escapeString(jQuery("#filter_name_save").val());
                    params.data_hash.schedule_config = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.schedule_config;
                    params.data_hash.date = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.date;
                  } else {
                    params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
                    params.data_hash.schedule_config = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.schedule_config;
                    params.data_hash.date = {};
                    
                    if(Helpkit.presetRangesSelected) {
                        params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
                        params.data_hash.date.presetRange = true;
                        params.data_hash.date.period = Helpkit.presetRangesPeriod;
                      } else {
                        params.data_hash.date.date_range = dateRange;
                        params.data_hash.date.presetRange = false;
                      }
                  }
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
            is_preset_selected = false;

            _this.flushAppliedFilters();
            _this.last_applied_saved_report_index = index;
            _this.save_util.last_applied_saved_report_index = index;
            var id = -1;

            if(index != -1) {

                var filter_hash = hash[index].report_filter;
                id = filter_hash.id;
                if(filter_hash.data_hash.date.presetRange) {
                    //Set the date range from saved range
                    var daterange = _this.save_util.convertPresetRangesToDate(filter_hash.data_hash.date.date_range,filter_hash.data_hash.date.period);
                    jQuery('#date_range').val(daterange);
                    Helpkit.presetRangesSelected = true;
                    Helpkit.presetRangesPeriod = filter_hash.data_hash.date.period;
                    is_preset_selected = true;
                }else{
                    jQuery('#date_range').val(filter_hash.data_hash.date.date_range);
                    Helpkit.presetRangesSelected = false;
                    is_preset_selected = false;
                }
                
                if(filter_hash.data_hash.report_filters != null) {
                   
                    jQuery.each(filter_hash.data_hash.report_filters, function(index, filter_row) {
                      var condition = filter_row.name;

                      if(condition == "group_by"){
                          //jQuery("#group_by_field").select2('val',filter_row.value);
                      } else if(condition == "customers_filter") {
                          _this._constructElasticSearchField(condition,filter_row.source);
                          jQuery('#'+ condition).select2('val',filter_row.value.split(','));
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
              Helpkit.presetRangesSelected = true;
              Helpkit.presetRangesPeriod = 'last_30';
            }

            _this.save_util.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
            _this.filterChanged = false;
             _this.save_util.filterChanged = false;
              //Set the flag that saved report was used
            _this.setFlag('true');
            jQuery("#submit").trigger('click');
            _this.save_util.cacheLastAppliedReport(id);
            
            _this.save_util.controls.hideSaveOptions();
            if(index != -1) {
                _this.save_util.controls.showDeleteAndEditOptions();
                _this.save_util.controls.showScheduleOptions(false);
            } else{
              _this.save_util.controls.hideDeleteAndEditOptions();
              _this.save_util.controls.showScheduleOptions(true);
            }
            var result = Helpkit.ScheduleUtil.isScheduled(
              _this.last_applied_saved_report_index,
              _this.save_util.default_report_is_scheduled,
              _this.save_util.default_index,
              Helpkit.report_filter_data
              );
            if(result.is_scheduled){
              Helpkit.ScheduleUtil.displayScheduleStatus(true,result.tooltip_title);
            } else{
              Helpkit.ScheduleUtil.displayScheduleStatus(false);
            }
            if(invalid_params_found) {
              //update the filter , removing the invalid params done in above loop
              _this.updateSavedReport(false);
            }
            
        },
        setFlag : function(val){
            jQuery('#is_saved_report').val(val);
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


function getPdfParams() {
  var remove = [];
  var params = {};
  var form_data = [];//jQuery('#report_filters').serializeArray(); 
  var filters_name = [ "customers_filter","user_id" ,"billable","products_id","group_id","ticket_type","priority","group_by_field"];
  params.data_hash = {};
  jQuery.each(filters_name,function(idx,condition) {
    var val = jQuery('#' + condition).select2('val');
    if(val != ""){
      var opt = {
          name : condition,
          value : val.toString()
      }
      form_data.push(opt);
    }
  });
  params.data_hash.date = {}
  params.data_hash.date.date_range = jQuery("#date_range").val();
  params.data_hash.date.presetRange = false;
  params.data_hash.report_filters = form_data;
  params.data_hash.select_hash = Helpkit.select_hash;
  if(savedReportUtil.last_applied_saved_report_index != -1){
    params.filter_name = Helpkit.report_filter_data[parseInt(savedReportUtil.last_applied_saved_report_index)].report_filter.filter_name;
  }
  return params;
}

function getFilterTextPDF(){
  var filters_name = [ "customers_filter","user_id" ,"billable","products_id","group_id","ticket_type","priority"];
  var labels = [
    I18n.t('helpdesk.time_sheets.customer'),
    I18n.t('helpdesk.time_sheets.agent'),
    I18n.t('helpdesk.time_sheets.billing_type'),
    I18n.t('helpdesk.time_sheets.group'),
    I18n.t('helpdesk.time_sheets.product'),
    I18n.t('helpdesk.time_sheets.ticket_type'),
    I18n.t('helpdesk.time_sheets.ticket_priority') ]; 
  var display = [];
  jQuery.each(filters_name,function(idx,name){
    var selected_options = [];
    var txt = "";
    selected_options = jQuery('#' + name).select2('data');
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
  Helpkit.select_hash = display;
}

function showResponseMessage(message) {
  jQuery("#email-reports-msg").remove();
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
  }, 1200);
    
} 

/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Freshfone = window.App.Freshfone || {};
(function ($){
  "user strict";
  App.Freshfonereports = {
    last_applied_saved_report_index : -1,
    CONST: {
        base_url : "/reports/phone/summary_reports",
        save_report   : "/save_reports_filter",
        delete_report : "/delete_reports_filter",
        update_report : "/update_reports_filter"
    },
    save_util : Helpkit.commonSavedReportUtil,
    filterChanged : false,
    filters : [ "freshfone_number" , "group_id" , "call_type" , "business_hours" ],
    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.start();
    },
    onLeave: function (data) {
      this.leave();
    },
    start: function () {
      this.bindHandlers();
      this.allNumberId=0;
      this.initializeSelect2Values();
      this.initSavedReports();
    },
    summaryReports: function (url) {
      var _this = this;
      jQuery('#loading-box').hide();
      var self = this;
      $('body').on('click.freshfone_reports',"#submit",function(ev){
        App.Phone.Metrics.recordReportsFilterState();
        if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
          jQuery('#sliding').click();
        }
        jQuery("#loading-box").show(); 
        jQuery("#freshfone_summary_report .report-page").css('opacity','0.2'); 
        jQuery("#loading-box").css('background','transparent'); 
        jQuery(".reports-loading").css('margin-top','330px'); 
        jQuery.ajax({
            url: url,
            type: "POST",
            data: self.filterParams(),
            success: function(data){ 
                jQuery("#loading-box").hide(); 
                jQuery("#freshfone_summary_report .report-page").css('opacity','1'); 
                jQuery("#freshfone_summary_report .report-page").removeClass('slide-shadow');
                jQuery(".reports-menu").addClass('hide');
                
                if(_this.filterChanged) {
                     _this.save_util.controls.hideDeleteAndEditOptions();
                     _this.save_util.controls.hideScheduleOptions();
                     _this.save_util.controls.showSaveOptions(_this.last_applied_saved_report_index); 
                }
              }
        });

      });
    },
    filterParams : function(){
      var filter_params = jQuery('#report_filters').serializeArray();
      filter_params.push({ name: "date_range_type", value : this.dateRangeType() });
      return filter_params
    },
    dateRangeType : function(){
      return $(".ui-widget-content li.ui-state-active").text().replace(/\s/g, "");
    },
    bindHandlers: function () {
      if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
          jQuery('#sliding').slide();
        }

      $('body').on('click.freshfone_reports','#cancel',function(){
          jQuery('#sliding').click();
      });

      //add the link which fire event on close button.
      $('body').on('click.freshfone_reports', '#filter-close-icon', function(){
          jQuery("#cancel").click();
      });

      $('body').on('click.freshfone_reports', '#export_as_csv', function () {
          $("#generate-pdf").trigger("click");
      });
    },
    groupOptions: function (filter_group_options, placeholder) {
      group_list = filter_group_options;

      jQuery('#group_id').select2({
          placeholder: placeholder,
          allowClear: true,
          data: {
            text: 'value',
            results:  group_list },
          formatResult: function (result) {
            return result.value;
          },
          formatSelection: function (result) {
            jQuery('#group_id').val(result.id);
            jQuery('#group_id').data('value', result.value);
            return result.value;
          }
        });
    },
    numberOptions: function(filter_number_options,selection) {
       var self=this;
        jQuery('#freshfone_number').select2({
          data: {
                text: 'value',
                results: filter_number_options },
          formatResult: function (result) {

          var formatedResult = "", ff_number = result.value;
          if(result.id==self.allNumberId){
          return formatedResult +="<b>" +result.value+ "</b></br>";
          } 
          
          if (result.name) {
            formatedResult += "<b>" + result.name + "</b><br>" + ff_number;
          } else {
            formatedResult += "<b>" + result.value + "</b>";
          }

          if (result.deleted) {
            formatedResult += "<i class='muted'> (Deleted)</i>"
          } 
          return formatedResult;
          },
          formatSelection: function (result) {
           if(result.id==self.allNumberId){
              return result.value;
            }
            else{
              return result.name==undefined ? result.value : result.name+" ("+result.value+")";
            } 
          },
        });
        jQuery("#freshfone_number").select2("data",selection);
    },
    businessHoursOptions: function (filter_business_hours_options,placeholder) {
      business_hours_list = filter_business_hours_options;

      $('#ff_business_hours').select2({
          placeholder: placeholder,
          dropdownCssClass : 'no-search',
          data: {
            text: 'value',
            results:  business_hours_list },
          formatResult: function (result) {
            return result.value;
          },
          formatSelection: function (result) {
            $('#ff_business_hours').val(result.business_hour_call);
            $('#ff_business_hours').data('value', result.value);
            return result.value;
          }
        });
    },
    initializeSelect2Values: function(){
      jQuery("#group_id").select2("val",freshfoneReports.group_cache);
      jQuery("#ff_business_hours").select2("val",freshfoneReports.business_hours_cache);
    }, 
    leave: function(){
      $('body').off('.freshfone_reports');
    },
    /* ---------- Save Report -------------- */
    initSavedReports : function(){
       this.bindSavedReportEvents();
       this.save_util.init();
       this.save_util.applyLastCachedReport();
    },
    bindSavedReportEvents : function() {
        var _this = this;
        jQuery(document).on('change', '.filter_item,.ff_item', function () { 
             _this.filterChanged = true;
             _this.save_util.filterChanged = true;
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
          _this.applySavedReport(data.index);
        });
        jQuery(document).on("presetRangesSelected", function(event,data) {
            Helpkit.presetRangesSelected = data.status;
            Helpkit.presetRangesPeriod = data.period;
            _this.filterChanged = true;
            _this.save_util.filterChanged = true;
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
                    _this.save_util.filterChanged = false;
                    _this.filterChanged = false;

                },
                error: function () {
                }
              },
              params : _this.getParams()
          };
          _this.save_util.saveHelper(opts);
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
    getParams : function() {
          var params = {};
          var form_data = [];
          var select_hash = [];
          var _this = this;

          params.data_hash = {};
          var labels = [
            I18n.t('reports.freshfone.number'),
            I18n.t('reports.freshfone.group'),
            I18n.t('reports.freshfone.call_type'),
            I18n.t('reports.freshfone.business_hours'),
          ]

          var dateRange = jQuery("#date_range").val();

          params.data_hash.date = {};
          if(Helpkit.presetRangesSelected) {
               params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
               params.data_hash.date.presetRange = true;
          } else {
               params.data_hash.date.date_range = dateRange;
               params.data_hash.date.presetRange = false;
          }

          jQuery.each(this.filters,function(idx,condition) {
                var cmp = jQuery("[name='" + condition + "']").select2('data');

                if(cmp != null) {
                     var val = cmp.id;
                     var text = cmp.value || cmp.text;
                      var opt = {
                          name : condition,
                          value : val
                      }
                      var select_obj = {
                           name : labels[idx],
                           value : text
                      }
                      form_data.push(opt);
                      select_hash.push(select_obj);
                }
           });
          params.data_hash.report_filters = form_data;
          params.data_hash.select_hash = select_hash;
          if(_this.last_applied_saved_report_index == -1 && !_this.filterChanged) {
            params.data_hash.default_report_is_scheduled = true;
          }
          return params;
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
        var is_preset_selected = false;

        _this.flushAppliedFilters();
        _this.last_applied_saved_report_index = index;
        _this.save_util.last_applied_saved_report_index = index;
        var id = - 1;

        if(index != -1) {

            var filter_hash = hash[index].report_filter;
            id = filter_hash.id;

            //Set the date range from saved range
            var date_hash = filter_hash.data_hash.date;
            var daterange;
            //Set the date range from saved range
            if(date_hash.presetRange) {
              daterange = _this.save_util.convertPresetRangesToDate(date_hash.date_range,date_hash.period);
              Helpkit.presetRangesSelected = true;
              Helpkit.presetRangesPeriod = filter_hash.data_hash.date.period;
              is_preset_selected = true;
            } else {
              daterange = date_hash.date_range;
              Helpkit.presetRangesSelected = false;
              is_preset_selected = false;
            }
            jQuery('#date_range').val(daterange);
            
            if(filter_hash.data_hash.report_filters != null) {
               
                jQuery.each(filter_hash.data_hash.report_filters, function(index, filter_row) {

                  var condition = filter_row.name;
                  //populate the value
                  var is_saved_param_valid = _this.checkValidityOfSavedParams(condition,filter_row.value);
                  
                  if (is_saved_param_valid) {
                     jQuery('#' + condition).select2('val',filter_row.value);
                  } else {
                    filter_hash.data_hash.report_filters.splice(index,1);
                    invalid_params_found = true;
                  }
              });
            }
        } else {
              var default_date_range = _this.save_util.convertDateDiffToDate(29);
              jQuery('#date_range').val(default_date_range);
        }

        _this.save_util.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
        _this.save_util.cacheLastAppliedReport(id);
        _this.filterChanged = false;
        _this.save_util.filterChanged = false;

        jQuery("#submit").trigger('click');

        _this.save_util.controls.hideSaveOptions();
        if(index != -1) {
            _this.save_util.controls.showDeleteAndEditOptions();
            _this.save_util.controls.showScheduleOptions(false);

            if(is_preset_selected){
              _this.save_util.controls.showScheduleOptions(false);
            } else{
              _this.save_util.controls.hideScheduleOptions();
            }
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
    checkValidityOfSavedParams : function() {
        return true;
    },
    flushAppliedFilters : function() {
        jQuery.each(this.filters,function(idx,filter_name){
            if(filter_name == "group_id" || filter_name == "business_hours") {
              jQuery("[name='" + filter_name + "']").select2('val','');
            } else {
              jQuery("[name='" + filter_name + "']").select2('val',0);  
            }
        });
    }
  };
})(jQuery);

function getPdfParams() {
  var params = {};
  var form_data = [];
  var select_hash = [];  
  var filters_arr = [ "freshfone_number" , "group_id" , "call_type" , "business_hours" ];
  var labels = [ I18n.t('reports.freshfone.number'),
                 I18n.t('reports.freshfone.group'),
                 I18n.t('reports.freshfone.call_type'),
                 I18n.t('reports.freshfone.business_hours') ] ;

  var dateRange = jQuery("#date_range").val();
  params.data_hash = {};
  params.data_hash.date = {};
  params.data_hash.date.date_range = dateRange;
  params.data_hash.date.presetRange = false;

  jQuery.each(filters_arr,function(idx,condition) {
    var cmp = jQuery("[name='" + condition + "']").select2('data');
    if(cmp != null) {
      var val = cmp.id;
      var text = cmp.value || cmp.text;
      if(condition === 'business_hours'){
        val = cmp.business_hour_call;
      }
      if(val != "") {
        var opt = {
            name : condition,
            value : val
        }
        var select_obj = {
             name : labels[idx],
             value : text
        }
        form_data.push(opt);
        select_hash.push(select_obj);
      }  
      else{
        if (condition == 'freshfone_number'){
          var opt = {
            name : condition,
            value : "0"
          }
          var select_obj = {
               name : labels[idx],
               value : text
          }
          form_data.push(opt);
          select_hash.push(select_obj);
        }
      }
    }

  });
  params.data_hash.report_filters = form_data;
  params.data_hash.select_hash = select_hash;
  if(App.Freshfonereports.last_applied_saved_report_index != -1){
    params.filter_name = Helpkit.report_filter_data[parseInt(App.Freshfonereports.last_applied_saved_report_index)].report_filter.filter_name;
  }
  return params;
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
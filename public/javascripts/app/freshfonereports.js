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
            data: jQuery('#report_filters').serializeArray(),
            success: function(data){ 
                jQuery("#loading-box").hide(); 
                jQuery("#freshfone_summary_report .report-page").css('opacity','1'); 
                jQuery("#freshfone_summary_report .report-page").removeClass('slide-shadow');
                jQuery(".reports-menu").addClass('hide');
                
                if(_this.filterChanged) {
                     _this.save_util.controls.hideDeleteAndEditOptions();
                     _this.save_util.controls.showSaveOptions(_this.last_applied_saved_report_index); 
                }
              }
        });

      });
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
            jQuery('#group_id').attr('value',result.id);
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
            $('#ff_business_hours').attr('value',result.business_hour_call);
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
          setTimeout(function(){
            jQuery('[data-action="pop-report-type-menu"]').trigger('click');
          },0);
          _this.applySavedReport(data.index);
        });
        jQuery(document).on("presetRangesSelected", function(event,status) {
            Helpkit.presetRangesSelected = status;
            _this.filterChanged = true;
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

        _this.flushAppliedFilters();
        _this.last_applied_saved_report_index = index;

        if(index != -1) {

            var filter_hash = hash[index].report_filter;

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
        _this.save_util.cacheLastAppliedReport(index);
        _this.filterChanged = false;

        jQuery("#submit").trigger('click');

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

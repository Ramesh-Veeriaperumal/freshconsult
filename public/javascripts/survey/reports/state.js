/*
    Module captures generic elements for making a
    request to fetch and parse data & maintains the URL state as well
*/

var SurveyState = {
    path: '/reports/custom_survey/',
    isRating:false,
    RemarksOnly:false,
    saved_report_used:false,
    TYPE:{1:"OVERVIEW",2:"RESPONSE"},
    OVERVIEW:{type:1,tab:"survey_overview_link",container:"survey_overview",disable:"survey_responses_link"},
    RESPONSE:{type:2,tab:"survey_responses_link",container:"survey_responses",disable:"survey_overview_link"},
    init:function(){
        SurveyState.save_util.init();
        SurveyState.save_util.applyLastCachedReport();
        SurveyState.bindSavedReportEvents();
        jQuery(window).bind( "hashchange", function(e) {
            SurveyReport.hideLayout();
            var state = jQuery.bbq.getState();
            state = Object.keys(state)[0];
            if(state){
                state = state.split("/")[1];
                var url = window.location.hash.slice(2);
                if(url.indexOf("/")!=-1){
                    var data = SurveyState.parse(url);
                    state = data.state;
                    SurveyState.setValues(data);
                }
                SurveyState.makeRequest(state);
            }else{
               SurveyOverview.fetch();
            }

            if(SurveyState.filterChanged) {
                 SurveyState.save_util.controls.hideDeleteAndEditOptions();
                 SurveyState.save_util.controls.showSaveOptions(SurveyState.last_applied_saved_report_index); 
            }
        });
        jQuery(window).trigger("hashchange");
    },
    setValues:function(data){
        var dateRange = SurveyDateRange.convertTimestampToDate(data.date_range);
        jQuery("#survey_report_survey_list").val(data.survey_id);
        jQuery("#survey_report_group_list").val(data.group_id);
        jQuery("#survey_report_agent_list").val(data.agent_id);
        this.setHeaderValues('select2-chosen-1','survey_report_survey_list');
        this.setHeaderValues('select2-chosen-2','survey_report_group_list');
        this.setHeaderValues('select2-chosen-3','survey_report_agent_list');
        if(data.rating){
            SurveyState.setFilter('rating_list',data.rating);
            jQuery('#rating_list').find('i').removeClass().addClass('survey-indicator '+SurveyConstants.iconClass[data.rating.id]+'');
        }
        jQuery('#survey_date_range_link').text(dateRange);
        dateRange = SurveyDateRange.convertTimestampToDateEn(data.date_range);
        jQuery('#survey_date_range').val(dateRange);
    },
    setHeaderValues:function(id,dropdownId){
        var value = jQuery('#'+dropdownId+ ' option:selected').text();
        jQuery('#'+id).text(value);
    },
    setFilter: function(id,obj){
      jQuery('#'+id).find('span.reports').text(obj.value);
      jQuery('#'+id).find('span.reports').attr('id',obj.id);
    },
    getFilter: function(id){
      return jQuery('#'+id).find('span.reports').attr('id');
    },
    parse:function(state){
        state = decodeURI(state);
        var data = {};
        var survey_id,group_id,agent_id,rating_id;
        var urlElements = state.split("/");
        if(urlElements.length>1){
            data.state = urlElements[0];
            data.survey_id  =  urlElements[1];
            data.group_id =  urlElements[2];
            data.agent_id = urlElements[3];
            if(data.state=="responses"){
                data.survey_question_id = urlElements[4];
                data.rating = SurveyState.getValue('survey_report_filter_by',urlElements[5],data.state); 
            }
            data.date_range = urlElements[urlElements.length-1];
        }
        return data;
    },
    getValue: function(id,value,type){
      var data ={};
      jQuery('#'+id+' ul li a').each(function(){
        if(jQuery(this).attr('id') == value){
            data.id = value;
            data.value = (type == 'responses') ? jQuery(this).attr('value') : jQuery(this).text().trim();
        }   
      });
      return data;
    },
    fetch:function(savedData){
        if(savedData){
          SurveyState.saved_report_used = true;
        }
        var root = jQuery(".report-panel-content").find('li.active').data('container').split("_")[1];
        var urlData = savedData || SurveyUtil.getUrlData();
        var rating = "all";
        var url = "/"+root+"/"+urlData.survey_id+"/"+urlData.group_id+"/"+urlData.agent_id;
        if(root=="responses"){
            var ratingVal = (SurveyState.isRating) ? SurveyState.getFilter('rating_list') : SurveyReportData.defaultAllValues.rating;
            url = url+"/"+urlData.survey_question_id+"/"+ratingVal;
        }
        url = url+"/"+urlData.date.date_range;
        jQuery.bbq.pushState(url,2);
    },
    makeRequest:function(state){
        if(state == 'overview'){
            jQuery("#survey_responses_link").removeClass('active');
            jQuery('#survey_overview_link').addClass('active');
            SurveyOverview.fetch();
        }else{
            jQuery("#survey_overview_link").removeClass('active');
            jQuery('#survey_responses_link').addClass('active');
            SurveyRemark.fetch();
        }
        jQuery('div#'+jQuery(".report-panel-content").find('li.active').data('hide-container')).hide();
        jQuery('div#'+jQuery(".report-panel-content").find('li.active').data('container')).show();
    },
    toggle:function(state){
       var stateObj = SurveyState[SurveyState.TYPE[state]];
       var tabObj = jQuery("#"+stateObj.tab);
       tabObj.addClass("active");
       jQuery("#"+stateObj.disable).removeClass("active");  
       jQuery('div#'+tabObj.data('hide-container')).hide();
       jQuery('div#'+tabObj.data('container')).show();
    },
    store:function(obj,divId){
        var id = jQuery(obj).attr('id');
        var value = jQuery(obj).text().trim();
        if(jQuery(obj).hasClass('rating_list')){
            SurveyState.isRating = true;
            value = jQuery(obj).attr('value');
            jQuery('#'+divId).find('i').removeClass().addClass('survey-indicator '+SurveyConstants.iconClass[id]+'');            
        }
        SurveyState.setFilter(divId,{'id':id ,'value':value});
    },

    // Saved Reports Functionalities

    last_applied_saved_report_index : -1,
    CONST: {
        base_url : '/reports/custom_survey',
        save_report   : "/save_reports_filter",
        delete_report : "/delete_reports_filter",
        update_report : "/update_reports_filter"
    },
    save_util : Helpkit.commonSavedReportUtil,
    filterChanged : false,
    bindSavedReportEvents: function(){
        jQuery(document).on("save.report",function() {
          SurveyState.saveReport();
        });
        jQuery(document).on("delete.report",function() { 
          SurveyState.deleteSavedReport();
        });
        jQuery(document).on("edit.report",function(ev,data) {
          SurveyState.updateSavedReport(data.isNameUpdate);
        });
        jQuery(document).on("apply.report",function(ev,data) {
          SurveyState.applySavedReport(data.index);
        });
        jQuery(document).on("discard_changes.report",function() {
          SurveyState.discardChanges();
        });
        jQuery(document).on("presetRangesSelected", function(event,status) {
            Helpkit.presetRangesSelected = status;
        });
    },
    formatFilterData: function(){
        var params = {};
        params.data_hash = SurveyUtil.getUrlData();
        if(Helpkit.presetRangesSelected) {
                var date_range = SurveyDateRange.convertTimestampToDateEn(params.data_hash.date.date_range);
               params.data_hash.date.date_range = SurveyState.save_util.dateRangeDiff(date_range);
               params.data_hash.date.presetRange = true;
          } 
        return params;
    },
    discardChanges : function() {
        SurveyState.applySavedReport(SurveyState.last_applied_saved_report_index);
    },
    applySavedReport : function(index) {
        var id = -1;
        if(index != -1){
           id = Helpkit.report_filter_data[index].report_filter.id;
        }
        SurveyState.save_util.cacheLastAppliedReport(id);
        if(index != -1) {
            var hash = Helpkit.report_filter_data;
            SurveyState.last_applied_saved_report_index = index;
            var data_hash = jQuery.extend(true,{},hash[index].report_filter.data_hash);
             if(data_hash.date.presetRange) {
              data_hash.date.date_range  = SurveyDateRange.convertDiffToTimestamp(data_hash.date.date_range);
            } 
            SurveyState.save_util.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
            SurveyState.filterChanged = false;
            SurveyState.save_util.controls.hideSaveOptions();
            SurveyState.save_util.controls.showDeleteAndEditOptions();
            SurveyState.fetch(data_hash);
        }
        else{
            window.location.href = SurveyState.CONST.base_url;
        }
    },
    saveReport : function() {
          var opts = {
              url: SurveyState.CONST.base_url + SurveyState.CONST.save_report,
              callbacks : {
                success: function () {
                    //update the last applied filter
                    SurveyState.last_applied_saved_report_index = this.new_id;
                    SurveyState.filterChanged = false;

                }
              },
              params : SurveyState.formatFilterData()
          };
          SurveyState.save_util.saveHelper(opts);
    },
    deleteSavedReport : function() {
          var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
          var opts = {
              current_selected_index : current_selected_index,
              url: SurveyState.CONST.base_url + SurveyState.CONST.delete_report,
              callbacks : {
                success: function (resp) {
                  SurveyState.applySavedReport(-1);
                }
              }
          };
          SurveyState.save_util.deleteHelper(opts);
    },
    updateSavedReport : function(isUpdateTitle) {
          var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
          var params = SurveyState.formatFilterData();

          if(isUpdateTitle) {
            params.filter_name = jQuery("#filter_name_edit").val();
          } else {
            params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
          }
          params.id = Helpkit.report_filter_data[current_selected_index].report_filter.id;

          var opts = {
              current_selected_index : current_selected_index,
              url: SurveyState.CONST.base_url + SurveyState.CONST.update_report,
              callbacks : {
                 success: function () {
                    SurveyState.filterChanged = false
               }
              },
              params : params
          };
          SurveyState.save_util.updateHelper(opts);
    },
}

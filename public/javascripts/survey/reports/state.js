/*
    Module captures generic elements for making a
    request to fetch and parse data & maintains the URL state as well
*/
var SurveyState = {
    path: '/custom_survey/reports/',
    isRating:false,
    RemarksOnly:false,
    TYPE:{1:"OVERVIEW",2:"RESPONSE"},
    OVERVIEW:{type:1,tab:"survey_overview_link",container:"survey_overview",disable:"survey_responses_link"},
    RESPONSE:{type:2,tab:"survey_responses_link",container:"survey_responses",disable:"survey_overview_link"},
    init:function(){
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
    fetch:function(label){
        var root = jQuery(".report-panel-content").find('li.active').data('container').split("_")[1];
        var urlData = SurveyUtil.getUrlData();
        var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
        var rating = "all";
        var url = "/"+root+"/"+urlData.survey_id+"/"+urlData.group_id+"/"+urlData.agent_id;
        if(root=="responses"){
            var ratingVal = (SurveyState.isRating) ? SurveyState.getFilter('rating_list') : SurveyReportData.defaultAllValues.rating;
            url = url+"/"+urlData.survey_question_id+"/"+ratingVal;
        }
        url = url+"/"+timestamp;
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
    }
}

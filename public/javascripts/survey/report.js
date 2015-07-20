/*
    Core module for reports.
*/
var SurveyDropDown = {
    rating:{
        default:{
            value:SurveyReportData.defaultAllValues.rating, 
            label:SurveyI18N.all
        }
    }
}

var SurveyReport = {
        init:function(){
            SurveyUtil.mapResults();
            SurveyUtil.reverseChoices();
            SurveyDateRange.init();
            SurveyState.init();
        },
        isEmptyChart:function(){
            var isEmpty = true;
            var values = Object.values(SurveyReportData.questionsResult);
            for(var i=0;i<values.length;i++){
                if(values[i].rating.length > 0){
                    isEmpty =  false;
                    break;
                }
            }
            if(isEmpty){
                var text = jQuery('#survey_overview_link').hasClass('active') ?  
                           SurveyI18N.no_overview :  SurveyI18N.no_remarks
                jQuery('div.empty-chart').text(text);
                SurveyReport.hideReport();
                return true;
            }
            return false;
        },
        hideReport:function(){
            jQuery('.nav.nav-pills').hide();
            jQuery('.report-panel-left .nav.nav-tabs').hide();
            jQuery('div#survey_report_summary').hide();
            jQuery('div#survey_overview').hide();
            jQuery('div#survey_responses').hide();
        },
        showReport:function(){
            jQuery('div.empty-chart').text('');
            jQuery('.nav.nav-pills').show();
            jQuery('div#survey_report_summary').show();
            jQuery('.report-panel-left .nav.nav-tabs').show();
        },
        showLayout:function(){
            jQuery('#survey_main_layout').show();
            jQuery('.report-panel-wrapper').show();
        },
        hideLayout:function(){
            jQuery('.report-panel-wrapper').hide();
        }
}

jQuery(document).ready(function(){     
    SurveyReport.init();
});

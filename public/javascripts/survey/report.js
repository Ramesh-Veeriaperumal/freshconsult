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
            }
            return isEmpty;
        },
        hideReport:function(){
            jQuery('div.empty-chart').show();
            jQuery('div.report-panel-content').hide();
            jQuery('div.report-panel-left').hide();
        },
        showReport:function(){
            jQuery('div.empty-chart').hide();
            jQuery('div.report-panel-content').show();
            jQuery('div.report-panel-left').show();
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

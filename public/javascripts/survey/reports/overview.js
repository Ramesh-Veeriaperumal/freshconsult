/*
    Module deals with activities relaed to overview.
*/
var SurveyOverview = {
        fetch:function(label){
            SurveyUtil.showOverlay();
            jQuery.ajax({
                type: 'GET',
                url: SurveyUtil.makeURL(),
                data: {},
                success:function(data){
                    SurveyUtil.hideOverlay();
                    SurveyUtil.updateData(data);
                    SurveyUtil.mapResults();
                    SurveyOverview.renderContent();
                    jQuery("#survey_report_main_content").unblock();
                    SurveyReport.showLayout();
                }
             });
        },
        renderContent:function(){            
            if(!SurveyReport.isEmptyChart()){
                SurveyReport.showReport();
                SurveyUtil.mapQuestionsResult();
                jQuery("#survey_report_main_content").html(
                    JST["survey/reports/template/content_layout"]({
                                    tab:SurveyTab.isRequired()
                    })
                );
                SurveyChart.create(SurveyUtil.whichSurvey().survey_questions[0]);
                SurveyTab.state();
            }
        }
}
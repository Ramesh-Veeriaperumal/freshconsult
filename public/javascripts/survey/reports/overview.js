/*
    Module deals with activities relaed to overview.
*/
var SurveyOverview = {
        fetch:function(label){
            SurveyUtil.showOverlay();
            jQuery.ajax({
                type: 'POST',
                data: {saved_report_used: SurveyState.saved_report_used},
                url: SurveyUtil.makeURL("aggregate_report"),
                success:function(data){
                    SurveyState.saved_report_used = false;
                    SurveyUtil.hideOverlay();
                    SurveyUtil.updateData(data);
                    SurveyUtil.mapResults();
                    SurveyOverview.renderContent();
                    jQuery("#survey_report_main_content").unblock();
                    SurveyReport.showLayout();
                    SurveyReportData.questionTableData = {};
                    SurveyTable.fetch();
                },
                error: function (error) {
                    console.log(error);
                }
             });
        },
        renderContent:function(){            
            if(!SurveyReport.isEmptyChart()){
                SurveyReport.showReport();
                SurveyUtil.mapQuestionsResult();
                jQuery("#survey_report_main_content").html(
                    JST["survey/reports/template/content_layout"]({
                        agentReporting: SurveyReport.agentReporting
                    })
                );
                SurveyChart.create(SurveyUtil.whichSurvey().survey_questions[0]);
                SurveyTab.renderSidebar();
            }
        }
}
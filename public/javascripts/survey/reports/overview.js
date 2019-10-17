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
            var widget_queries_present = window.location.href.split("?")[1];
            var widget_queries = (widget_queries_present) ? widget_queries_present.split("&") : false;

            if (widget_queries && SurveyState.dashboard_widget_request) {
                jQuery("#survey_report_group_list").val(widget_queries[0].split("=")[1]).trigger('change.select2');
                SurveyState.dashboard_widget_request = false;
            }

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
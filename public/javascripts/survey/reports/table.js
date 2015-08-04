/*
    Module handles table related activities in overview page.
*/
var SurveyTable = {
    notRequired:function(){
        return ((SurveyReportData.groupWiseReport=="null" || !SurveyReportData.groupWiseReport) &&
                (SurveyReportData.agentWiseReport=="null" || !SurveyReportData.agentWiseReport))
    },
    reset:function(questionId,tabRef){
        jQuery("#survey_table").html(
            JST["survey/reports/template/stats_detail_table"]({
                    table:this.format(jQuery('#viewReportBy').attr('value'),questionId,tabRef.name)
            })
        );
    },
    whichReport:function(type,questionName){
        var report;
        var reports = (type == SurveyReportData.defaultAllValues.group) ? SurveyReportData.groupWiseReport
                                                                        : SurveyReportData.agentWiseReport;
        if(questionName && reports){
            report = reports[questionName];
        }
        else{
            report = reports[Object.keys(reports)[0]];
        }
        return report;
    },
    whichChoices:function(questionId){
        var survey = SurveyUtil.whichSurvey();
        var questions = survey.survey_questions;
        var choices = questions[0].choices;
        if(questionId){
            choices = '';
            for(var i=0;i<questions.length;i++){
                if(questions[i].id == questionId){
                    choices = questions[i].choices;
                }
            }
        }
        return choices;
    },
    format:function(type,questionId,questionName){
        var reportType = type ? type : SurveyReportData.defaultAllValues.group;
        if(this.notRequired()){
            this.type.hide();
            return;
        }
        reportType = this.type.get(reportType);
        var choices = this.whichChoices(questionId);
        var tableFormat = new Array();
        var header = new Array();
        (reportType == SurveyReportData.defaultAllValues.group) ? header.push(SurveyI18N.group)
                                                                : header.push(SurveyI18N.agent);
        for(var i=0;i<choices.length;i++){
            header.push(choices[i].value);
        }
        header.push(SurveyI18N.total_responses);
        tableFormat.push(header);
        var report = this.whichReport(reportType,questionName);
        _.each(report,function(info){
                var choice = new Array();
                choice.push(info.name);
                for(var i=0;i<choices.length;i++){
                    choice.push((info.rating[choices[i].face_value] || 0));
                }
                choice.push(info.total);
                tableFormat.push(choice);
        });
        return tableFormat;
    },
    draw:function(){
        jQuery('#report_tabular_data').dataTable({
            "bFilter" :false,
            "bInfo":false,
            "bLengthChange":false,
            "bSort":true,
            "bDestroy" :true,
            "pagingType":"simple_numbers",
            "sDom": '<"row view-filter"<"col-sm-12"<"pull-left"l><"pull-right"f><"clearfix">>>t<"row view-pager"<"col-sm-12"<"text-center"ip>>>',
            "bSearch" :false,
            "iDisplayLength" : 10
        });
        jQuery('#report_tabular_data').show();

        jQuery('#report_tabular_data tbody tr').live('click',function () {
            var values =  jQuery('#report_tabular_data').dataTable().fnGetData(this);
            if(jQuery('#viewReportBy').attr('value') == SurveyReportData.defaultAllValues.group){
                SurveyTable.type.filter('survey_report_group_list',values[0],jQuery('#viewReportBy').attr('value'));
            }else{
                SurveyTable.type.filter('survey_report_agent_list',values[0],jQuery('#viewReportBy').attr('value'));
            }
        });
    },
    type:{
        get: function(type){
           if(jQuery('#survey_report_group_list').val() != SurveyReportData.defaultAllValues.group
                            && SurveyReportData.agentWiseReport != null){
                type = SurveyReportData.defaultAllValues.agent;
                this.hide(type);
            }
            else if(jQuery('#survey_report_agent_list').val() != SurveyReportData.defaultAllValues.agent
                            && SurveyReportData.groupWiseReport != null){
                type = SurveyReportData.defaultAllValues.group;
                this.hide(type);
            }
            return type;
        },
        change: function(obj){
            var type = jQuery(obj).attr('value');
            var tabRef = SurveyUtil.findQuestion(jQuery('.tabs-survey').find('li.active').data('id'));
            if(!tabRef){
                tabRef = SurveyUtil.whichSurvey().survey_questions[0];
            }
            jQuery('#viewReportBy').find('li').removeClass('active');
            jQuery('#viewReportBy').attr('value',type);
            jQuery(obj).parent().addClass('active');
            jQuery("#survey_table").html(JST["survey/reports/template/stats_detail_table"]({
                table:SurveyTable.format(type,tabRef.id,tabRef.name)
            }));
        },
        hide: function(type){
            setTimeout(function(){
                type ? jQuery('#viewReportBy').attr('value',type) : '';
                jQuery('#reportView').hide();
            }, 0);
        },
        filter: function(id,value,type){
          var dropdown_value = '';
          jQuery('#'+id+'> option').each(function(){
                if(jQuery(this).text() == value){
                    dropdown_value = jQuery(this).val();
                    return false;
                }
            });
            jQuery('#'+id).val(dropdown_value);
            if(type == SurveyReportData.defaultAllValues.group){
                jQuery('#select2-chosen-2').text(value);
                SurveyGroup.change(jQuery('#'+id));
            }else{
                jQuery('#select2-chosen-3').text(value);
                SurveyAgent.change(jQuery('#'+id))
            }
        }
    }
}

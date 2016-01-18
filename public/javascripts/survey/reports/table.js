/*
    Module handles table related activities in overview page.
*/
var SurveyTable = {
    notRequired:function(){  
        return (SurveyReportData.TableFormatData=="null" || !SurveyReportData.TableFormatData) 
    },
    reset:function(questionId,tabRef){
        SurveyTable.fetch();
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
        if(type=="none"){
            return;
        }
        var reportType = type ? type : SurveyReportData.defaultAllValues.group;
        var i;
        if(this.notRequired()){
            this.type.hide();
            return;
        }
        else{
            jQuery('#reportView').show();
        }
        reportType = this.type.get(reportType);
        var choices = this.whichChoices(questionId);
        var tableFormat = [];
        var header = [];
        (reportType == SurveyReportData.defaultAllValues.group) ? header.push(SurveyI18N.group)
                                                                : header.push(SurveyI18N.agent);
        var choice_none = {name: "None",choices: [],total: 0};
        for(var i=0;i<choices.length;i++){
            header.push(choices[i].value);
            choice_none.choices[i]=0;
        }
        header.push(SurveyI18N.total_responses);
        tableFormat.push(header);
        var report = SurveyReportData.TableFormatData;
        
        _.each(report,function(info){
            var dataRow = {choices: []};
            var name = SurveyUtil.getDataName(info.id,reportType);
            if(name){
                dataRow.name = name;
                for(i=0;i<choices.length;i++){
                    dataRow.choices[i] = (info.rating[choices[i].face_value] || 0);
                }
                dataRow.total = info.total;
                tableFormat.push(dataRow);
            }
            else{
                for(i=0;i<choices.length;i++){
                    choice_none.choices[i] += info.rating[choices[i].face_value] || 0;
                }
                choice_none.total += info.total;
            }
        });
        if(choice_none.total!=0){
            tableFormat.push(choice_none);
        }
        return tableFormat;
    },
    draw:function(count){
        jQuery('#report_tabular_data').dataTable({
            "bFilter" :false,
            "bInfo":false,
            "bLengthChange":false,
            "bSort":true,
            "bDestroy" :true,
            "bPaginate" : (count>10)? true:false,
            "pagingType":"simple_numbers",
            "sDom": '<"row view-filter"<"col-sm-12"<"pull-left"l><"pull-right"f><"clearfix">>>t<"row view-pager"<"col-sm-12"<"text-center"ip>>>',
            "bSearch" :false,
            "iDisplayLength" : 10,
            "oLanguage": {
                "oPaginate": {
                    "sNext": ">",
                    "sPrevious": "<"
                }
            }
        });
        jQuery('#report_tabular_data').show();

        jQuery('#report_tabular_data tbody tr:not(".exclude_none")').live('click',function () {
            var values =  jQuery('#report_tabular_data').dataTable().fnGetData(this);
            if(jQuery('#viewReportBy').attr('value') == SurveyReportData.defaultAllValues.group){
                SurveyTable.type.filter('survey_report_group_list',values[0],jQuery('#viewReportBy').attr('value'));
            }else{
                SurveyTable.type.filter('survey_report_agent_list',values[0],jQuery('#viewReportBy').attr('value'));
            }
        });
    },
    renderTable:function(type){
        var tabRef = SurveyUtil.findQuestion(jQuery('.tabs-survey').find('li.active').data('id'));
        if(!tabRef){
            tabRef = SurveyUtil.whichSurvey().survey_questions[0];
        }
        jQuery("#survey_table").html(JST["survey/reports/template/stats_detail_table"]({
            table:SurveyTable.format(type,tabRef.id,tabRef.name)
        }));
    },
    fetch:function(){
        var url_type, report_type;
        var urlData = SurveyUtil.getUrlData();
        if(urlData.group_id == SurveyReportData.defaultAllValues.group){
            url_type = 'group_wise_report';
            report_type = SurveyReportData.defaultAllValues.group;   
            if(urlData.agent_id == SurveyReportData.defaultAllValues.agent){
                report_type = jQuery('#viewReportBy').attr('value');
                url_type = (report_type == SurveyReportData.defaultAllValues.group)? 'group_wise_report' : 'agent_wise_report';
            }             
        }
        else if (urlData.agent_id == SurveyReportData.defaultAllValues.agent){

            url_type = 'agent_wise_report';   
            report_type = SurveyReportData.defaultAllValues.agent; 
        }
        else{
            report_type = "none";
            SurveyReportData.TableFormatData = {};
            SurveyTable.renderTable(report_type);
            return;
        }
        
        if(SurveyReportData.questionTableData[urlData.survey_question_id] && SurveyReportData.questionTableData[urlData.survey_question_id][report_type]){
            SurveyReportData.TableFormatData = SurveyReportData.questionTableData[urlData.survey_question_id][report_type];
            SurveyTable.renderTable(report_type);
        }
        else{
            SurveyUtil.showOverlay();
            jQuery.ajax({
                type: 'GET',
                url: SurveyUtil.makeURL(url_type),
                success:function(data){
                    SurveyUtil.updateTableData(data,urlData.survey_question_id,report_type);
                    SurveyTable.renderTable(report_type);
                    SurveyUtil.hideOverlay();
                },
                error: function (error) {
                    console.log(error);
                }
            });
        }
    },
    type:{
        get: function(type){
           if(jQuery('#survey_report_group_list').val() != SurveyReportData.defaultAllValues.group){
                type = SurveyReportData.defaultAllValues.agent;
                this.hide(type);
            }
            else if(jQuery('#survey_report_agent_list').val() != SurveyReportData.defaultAllValues.agent){
                type = SurveyReportData.defaultAllValues.group;
                this.hide(type);
            }
            return type;
        },
        change: function(obj){
            var type = jQuery(obj).attr('value');
            jQuery('#viewReportBy').find('li').removeClass('active');
            jQuery('#viewReportBy').attr('value',type);
            jQuery(obj).parent().addClass('active');
            SurveyTable.fetch();

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

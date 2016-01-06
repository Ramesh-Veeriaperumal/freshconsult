/*
    Module deals with the life cycle of tabs.
*/
var SurveyTab = {
        activeTab: '',
        inactivate:function(tab){
            tab.removeClass("active").addClass("inactive");
        },
        activate:function(tab){
            tab.removeClass("inactive").addClass("active");
            this.ToolTip.removeToolTip(jQuery(tab).find('a'));
        },
        inactivateAll:function(){
            var tabs = jQuery(".nav-survey-rating");
            for(var i=0;i<tabs.length;i++){
                this.inactivate(jQuery(tabs[i]));
            }
        },
        change:function(tabId,type,renderFlag){ 
            SurveyTab.activeTab = {"id":tabId , "type" : type};
            this.inactivateAll();
            this.activate(jQuery("#"+tabId+"_"+type));
            var tabRef = SurveyUtil.findQuestion(tabId);
            SurveySummary.reset(type,tabId);
            if(jQuery('#survey_overview_link').hasClass('active')){
                SurveyChart.create(tabRef);
                SurveyTable.reset(tabRef.id,tabRef);
            }
            else{
                if(renderFlag){
                    SurveyRemark.renderFilterBy();
                    SurveyState.RemarksOnly = true;
                    SurveyState.fetch();
                }
            } 
        },
        data:function(){
           var survey = SurveyUtil.whichSurvey();
           var tabs = [];
           var q_length = survey.survey_questions.length;
            for(var i=0;i<q_length;i++){
                var question = survey.survey_questions[i];
                var tab = this.format(question);
                tab.disabled = (!question.rating) ? "disable" : "";
                if(0 === i){
                    tab.title = SurveyI18N.overall_rating;
                }else{
                    tab.title = SurveyI18N.question+i;
                }
                tab.type = SurveyReportData.type.question;
                tab.state = (i==0) ? "active" : "inactive";
                tabs.push(tab);
            }

            return tabs;
        },
        format:function(data){
            var tab = SurveyUtil.consolidatedPercentage(data,true);
            tab.id = data.id;
            tab.overallStatus = "neutral";
            if((tab.happy.percentage>tab.unhappy.percentage) 
                                && (tab.happy.percentage>tab.neutral.percentage)){tab.overallStatus="happy";}
            else if((tab.unhappy.percentage>=tab.neutral.percentage) 
                                && (tab.unhappy.percentage>=tab.happy.percentage)){tab.overallStatus="unhappy";}
            return tab;
        },
        isRequired:function(){
            return SurveyUtil.isQuestionsExist();
        },        
        renderSidebar:function(){
                if(SurveyTab.isRequired()){
                    jQuery("#survey_report_sidebar").html(
                        JST["survey/reports/template/stats_tab_layout"]()
                    );
                    jQuery('.report-panel-content').removeClass('no_questions');
                    SurveyTab.state();
                }
                else{
                    jQuery("#survey_report_sidebar").html("");
                    jQuery('.report-panel-content').addClass('no_questions');
                }
        },
        state:function(){
            if(SurveyTab.activeTab != ''){
                SurveyTab.change(SurveyTab.activeTab["id"],SurveyTab.activeTab["type"],false);
            }
        },
        resetState:function(){
          SurveyTab.activeTab = '';
        },
        ToolTip:{
            showToolTip:function(object,id,type,title){
                if(jQuery(object).parent().hasClass('active')){
                    return;
                }
                var data = jQuery(object).find('div#summary-content');
                data.empty();
                data.html(JST["survey/reports/template/content_summary"]({
                        data:SurveySummary.create(type,id,true)
                }));
                if(!SurveyUtil.findQuestion(id).default){
                    data.find('.well-survey').prepend("<div class='survey-tooltip-title pull-left'>"+title+ ". </div>");
                }
                data.find('.survey-answers').remove();
                data.find('.muted').remove();
                jQuery(object).qtip({
                  style: {
                    classes:'ui-tooltip-light ui-tooltip-rounded ui-tooltip-shadow custom-survey-tooltip'
                  },
                  content: {
                    text: data.html(),
                  },
                  position: { 
                    type: 'absolute',
                    my: 'left middle',
                    at: 'right  middle'
                  },
                  overwrite: false,
                  show: {
                    delay: 500,
                    ready: true
                  },
                  hide: {
                    fixed: true,
                    delay: 500
                  }
                });
            },
            removeToolTip: function(object){
                jQuery(object).qtip('destroy');
            }
        }
    }

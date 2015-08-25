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
        change:function(tabId,type){ 
                SurveyTab.activeTab = {"id":tabId , "type" : type};
                this.inactivateAll();
                this.activate(jQuery("#"+tabId+"_"+type));
                var tabRef = null;
                tabRef = SurveyUtil.findQuestion(tabId);         
                SurveyChart.create(tabRef);
                SurveyTable.reset(tabRef.id,tabRef);
                SurveySummary.reset(type,tabId);
        },
        data:function(){
           var survey = SurveyUtil.whichSurvey();
           var tabs = [];
            for(var i=0;i<survey.survey_questions.length;i++){
                var question = survey.survey_questions[i];
                if(!question.rating){continue;}
                var tab = this.format(question);
                if(i == 0){
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
            var tab = SurveyUtil.consolidatedPercentage(data);
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
        state:function(){
            if(SurveyTab.activeTab != ''){
                SurveyTab.change(SurveyTab.activeTab["id"],SurveyTab.activeTab["type"]);
            }
        },
        resetState:function(){
          SurveyTab.activeTab = '';
        },
        ToolTip:{
            showToolTip:function(object,id,type){
                if(jQuery(object).parent().hasClass('active')){
                    return;
                }
                var data = jQuery(object).find('div#summary-content');
                data.empty();
                data.html(JST["survey/reports/template/content_summary"]({
                        data:SurveySummary.create(type,id)
                }));
                data.find('ul').remove();
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

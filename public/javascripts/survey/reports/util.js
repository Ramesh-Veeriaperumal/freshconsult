/*
    Utilities that can be used across different modules.
*/
var SurveyUtil = {
        smiley: {
             "HAPPY" : "ficon-survey-happy",
             "NEUTRAL" : "ficon-survey-neutral",
             "UNHAPPY" : "ficon-survey-sad"
        },
        whichSurvey:function(){
            var surveySelectComponent = jQuery("#survey_report_survey_list");
            var selectedSurvey = SurveyReportData.surveysList[0];
            for(var i=0;i<SurveyReportData.surveysList.length;i++){
                if((surveySelectComponent && 
                    SurveyReportData.surveysList[i].id==surveySelectComponent.val())){
                    selectedSurvey = SurveyReportData.surveysList[i];
                    break;
                }
            }
            return selectedSurvey;
        },	   
        reverseChoices:function(){
           for(var i=0;i<SurveyReportData.surveysList.length;i++){
                var survey = SurveyReportData.surveysList[i];
                survey.choices = JSON.parse(survey.choices);
                survey.choices.reverse();
                var questions = survey.survey_questions;
                if(questions){
                    for(var j=0;j<questions.length;j++){
                        questions[j].choices.reverse();
                    }
                }
           }
        },
        updateData:function(data){
             SurveyReportData.unanswered = data.unanswered;
             SurveyReportData.questionsResult = JSON.parse(data.questions_result);
             SurveyReportData.groupWiseReport = JSON.parse(data.group_wise_report);
             SurveyReportData.agentWiseReport = JSON.parse(data.agent_wise_report);
        },
        updateState:function(){
          SurveyState.isRating = false;
        },
        mapResults:function(){
            var survey = SurveyUtil.whichSurvey();
            this.mapQuestionsResult();
        },
        mapQuestionsResult:function(){
            var survey = SurveyUtil.whichSurvey();
            if(survey.survey_questions.length==0){
                return;
            }
            var questionChoices = survey.survey_questions[0].choices;
            var results = [];
            for(var i=0;i<survey.survey_questions.length;i++){
                  survey.survey_questions[i]["rating"] = this.ratingFormat(SurveyUtil.findQuestionResult(survey.survey_questions[i].name));
            }
        },
        makeURL:function(root){
            if(!root){ root=""; }
            var surveyObj = jQuery("#survey_report_survey_list");
            var groupObj = jQuery("#survey_report_group_list");
            var agentObj = jQuery("#survey_report_agent_list");
            var timestamp = SurveyDateRange.convertDateToTimestamp(jQuery("#survey_date_range").val());
            var rating = "all";
            var url = surveyObj.val()+"/"+groupObj.val()+"/"+agentObj.val();
            if(root=="remarks"){
                var ratingVal = SurveyState.getFilter('rating_list');
                if(ratingVal==undefined){ ratingVal = "r"; }
                url = root+"/"+url+"/"+ratingVal;
            }
            url = SurveyState.path + url + "/"+timestamp;
            
            return url;
        },  
        isQuestionsExist:function(){
            var surveyQuestions = SurveyUtil.whichSurvey().survey_questions;
            return ((surveyQuestions && surveyQuestions.length>1) ? true : false);
        },
        findQuestionResult:function(name){
                if(SurveyReportData.questionsResult && SurveyReportData.questionsResult[name]){
                    return SurveyReportData.questionsResult[name]["rating"];
                }
        },
        findQuestion:function(id){
                var survey_questions = SurveyUtil.whichSurvey().survey_questions;
                if(!survey_questions || survey_questions.length==0){return;}
                for(var i=0;i<survey_questions.length;i++){
                        if(survey_questions[i].id==id){
                                return survey_questions[i];
                        }
                }
        },
        ratingFormat:function(obj){
            var newObj = {};
            if(!obj || obj.length==0){return;}
            for(var i=0;i<obj.length;i++){
                 newObj[obj[i]["rating"]] = obj[i]["total"];
            }
            return newObj;
        },
        ratingKey:function(rating){
            if(rating>0){ return "happy";}
            else if(rating<0){ return "unhappy";}
            else{return "neutral";}
        },
        findSmiley:function(rating){
            var smileyKey = "NEUTRAL";
            if(rating>SurveyConstants.rating.NEUTRAL){ smileyKey = "HAPPY"; }
            else if(rating<SurveyConstants.rating.NEUTRAL){ smileyKey="UNHAPPY"; }
            return SurveyUtil.smiley[smileyKey];
        },
        consolidatedPercentage:function(data,type){
            var percentile = new Object({
                    happy: {
                        count:0,
                        smiley: SurveyUtil.smiley["HAPPY"],
                        status: SurveyI18N.positive
                    },
                    neutral: {
                        count:0,
                        smiley: SurveyUtil.smiley["NEUTRAL"],
                        status: SurveyI18N.neutral
                    },
                    unhappy: {
                        count:0,
                        smiley: SurveyUtil.smiley["UNHAPPY"],
                        status: SurveyI18N.negative
                    }
            });

            if(data){
                var rating = data["rating"];
                for(var key in rating){
                        if(key>SurveyConstants.rating.NEUTRAL){
                            percentile.happy.count+=rating[key];
                        }
                        else if(key<SurveyConstants.rating.NEUTRAL){
                            percentile.unhappy.count+=rating[key];
                        }
                        else{
                            percentile.neutral.count+=rating[key];
                        }
                }
                
                var totalRating = percentile.happy.count+percentile.neutral.count+percentile.unhappy.count;
                for(var key in percentile){
                    if(!totalRating){
                            percentile[key].percentage = 0;
                    }
                    else{
                            percentile[key].percentage = Math.round((percentile[key].count/totalRating)*100);
                    }
                }
            }
           
            return percentile;
            
        },
        getDateString:function(dtString){
            var date = new Date(dtString);
            return SurveyI18N.month_names[(date.getMonth()+1)]+" "+date.getDate()+", "+(date.getYear()+1900);
        },
        showOverlay:function(){
            jQuery('.survey-overlay').show();
        },
        hideOverlay:function(){
            jQuery('.survey-overlay').hide();
        },
        rating:{
            choice:function(){
                var negativeOptions = [];
                var positiveOptions = [];
                var neutralOptions = []; 
                var choices  = SurveyUtil.whichSurvey().choices;
                for(var c=0;c<choices.length;c++){
                    if(choices[c].survey_question_choice.face_value == SurveyConstants.rating.EXTREMELY_UNHAPPY || 
                        choices[c].survey_question_choice.face_value == SurveyConstants.rating.VERY_UNHAPPY ||
                        choices[c].survey_question_choice.face_value == SurveyConstants.rating.UNHAPPY){
                          negativeOptions.push(SurveyUtil.rating.getChoiceFormat(choices[c],SurveyI18N.negative));
                    }else if(choices[c].survey_question_choice.face_value == SurveyConstants.rating.NEUTRAL){
                          neutralOptions.push(SurveyUtil.rating.getChoiceFormat(choices[c],SurveyI18N.neutral));
                    }else{
                          positiveOptions.push(SurveyUtil.rating.getChoiceFormat(choices[c],SurveyI18N.positive));
                    }
                }
                SurveyUtil.rating.sort(positiveOptions);
                SurveyUtil.rating.sort(negativeOptions);
                var options = [];
                (neutralOptions.length > 0) ? options.push(positiveOptions,neutralOptions,negativeOptions) : 
                                              options.push(positiveOptions,negativeOptions);
                return options;
            },
            sort:function(array){
                array.sort(function(a,b){
                    return parseInt(b.value) - parseInt(a.value);
                });
            },
            arrayToHash:function(choices){
                var choices = choices || SurveyUtil.whichSurvey().choices;
                var choiceMap = {};
                for(var i=0;i<choices.length;i++){
                        choiceMap[choices[i].survey_question_choice.face_value] = choices[i].survey_question_choice.value;                }
                return choiceMap;
            },
            text:function(rating){
              var survey = SurveyUtil.whichSurvey();
              if(!survey.choiceMap){ survey.choiceMap = this.arrayToHash(); }
              return survey.choiceMap[rating];
            },
            style:function(rating){
                return SurveyReportData.customerRatingsStyle[rating];
            },
            getChoiceFormat:function(choice,type){
             return {
                      value: ""+choice.survey_question_choice.face_value,
                      label: choice.survey_question_choice.value,
                      class: SurveyConstants.iconClass[""+choice.survey_question_choice.face_value],
                      type: type
                    };
            },
            filter:function(obj){
              SurveyState.store(obj,'rating_list');
              SurveyState.fetch();
             }
        }
}
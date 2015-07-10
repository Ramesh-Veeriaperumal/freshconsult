/*
    Module deals with activities related to summary contents.
*/
var SurveySummary = {
        reset:function(type,id){            
            jQuery("#survey_report_summary").html( 
                JST["survey/reports/template/content_summary"]({
                        data:this.create(type,id)
                })
            );
        },
        create:function(type,id){
            var rating = SurveyState.getFilter('rating_list');
            type = (type || SurveyReportData.type.rating);
            var protocol = {
                type: type,
                rating: rating,
                isRatingFilter: this.isRatingFilter(type)
            };
            data = this.whichData(type,id);
            protocol.question = (data.link_text || data.label);
            protocol.percentile = SurveyUtil.consolidatedPercentage(data);
            var totalRating = protocol.percentile.happy.count+protocol.percentile.neutral.count+protocol.percentile.unhappy.count;
            protocol.answered = totalRating;
            protocol.unanswered = SurveyReportData.unanswered;
            if(protocol.isRatingFilter){
                var rating = 0;
                if(data.rating){
                    rating = data.rating[protocol.rating];
                }
                protocol.ratingText = jQuery('#rating_list').find('span.reports').attr('value');
                protocol.ratingPercentage = Math.round((parseInt(rating)/totalRating)*100) || 0;
                protocol.ratingSmiley = SurveyUtil.findSmiley(protocol.rating);
                protocol.ratingCount = rating ? rating : 0 ;
            }
            return protocol;
        },
        whichData:function(type,id){
                return (( type==SurveyReportData.type.rating || 
                              type==SurveyReportData.type.remarks || 
                              this.isRatingFilter(type) ) ? SurveyUtil.whichSurvey().survey_questions[0] : SurveyUtil.findQuestion(id));
        },
        isRatingFilter:function(type){
            return !(type==SurveyReportData.type.rating || type==SurveyReportData.type.question || 
                        (type==SurveyReportData.type.remarks && (!jQuery('#rating_list').find('span.reports').attr('id') || 
                        jQuery('#rating_list').find('span.reports').attr('id')==SurveyDropDown.rating.default.value)));
        }
    }
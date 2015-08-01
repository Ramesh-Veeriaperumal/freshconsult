  var surveysI18n = {};
  surveysI18n = {};
  surveysI18n.title_text = "<%= t('admin.surveys.new_questions_layout.title_text') %>";
  surveysI18n.add_question = "<%= t('admin.surveys.new_questions_layout.add_question') %>";
  surveysI18n.questions = "<%= t('admin.surveys.new_questions_layout.questions') %>";
  surveysI18n.content_text = "<%= t('admin.surveys.new_rating.content_text')%>";
  surveysI18n.survey_question = "<%= t('admin.surveys.new_rating.survey_question')%>";
  surveysI18n.error_text = "<%= t('admin.surveys.new_rating.error_text') %>";
  surveysI18n.points_scale = "<%= t('admin.surveys.new_rating.points_scale') %>";

  surveysI18n.survey_feedback = "<%= t('admin.surveys.new_thanks.survey_feedback')%>";
  surveysI18n.thanks_feedback =  "<%= t('admin.surveys.new_thanks.thanks_feedback')%>";
  surveysI18n.additional_comments_feedback = "<%= t('admin.surveys.new_thanks.additional_comments_feedback')%>";
  surveysI18n.comments_feedback = "<%= t('admin.surveys.new_thanks.comments_feedback')%>";
  surveysI18n.thanks_message_feedback = "<%= t('admin.surveys.new_thanks.thanks_message_feedback')%>";
  surveysI18n.default_survey = "<%= t('admin.surveys.new_layout.default_survey') %>";
  surveysI18n.default_question_text = "<%= t('admin.surveys.new_thanks.default_question_text') %>";

  surveysI18n.send_while_option1 = " <%= t('admin.surveys.satisfaction_settings.send_while_option1') %>";
  surveysI18n.send_while_option2 = " <%= t('admin.surveys.satisfaction_settings.send_while_option2') %>";
  surveysI18n.send_while_option3 = " <%= t('admin.surveys.satisfaction_settings.send_while_option3') %>";
  surveysI18n.send_while_option4 = " <%= t('admin.surveys.satisfaction_settings.send_while_option4') %>";
  surveysI18n.send_while_title = " <%= t('admin.surveys.satisfaction_settings.send_while_title') %>";
  surveysI18n.link_text_input = " <%= t('admin.surveys.satisfaction_settings.link_text_input') %>";
  surveysI18n.enable_label = " <%= t('admin.surveys.satisfaction_settings.enable_label') %>";

  surveysI18n.strongly_disagree= "<%= t('admin.surveys.choice_contents.strongly_disagree') %>";
  surveysI18n.some_what_disagree= "<%= t('admin.surveys.choice_contents.some_what_disagree') %>";
  surveysI18n.disagree= "<%= t('admin.surveys.choice_contents.disagree') %>";
  surveysI18n.neutral= "<%= t('admin.surveys.choice_contents.neutral') %>";
  surveysI18n.agree= "<%= t('admin.surveys.choice_contents.agree') %>";
  surveysI18n.some_what_agree= "<%= t('admin.surveys.choice_contents.some_what_agree') %>";
  surveysI18n.strongly_agree= "<%= t('admin.surveys.choice_contents.strongly_agree') %>";

  surveysI18n.title_text = "<%= t('admin.surveys.thanks_contents.title_text') %>";
  surveysI18n.message_text = "<%= t('admin.surveys.thanks_contents.message_text')%>";
  surveysI18n.label_text = "<%= t('admin.surveys.thanks_contents.label_text')%>";

  surveysI18n.saving_survey = "<%= t('admin.surveys.index.saving_survey') %>";
  surveysI18n.editing_survey = "<%= t('admin.surveys.index.editing_survey')%>";
  surveysI18n.deleting_survey = "<%= t('admin.surveys.index.deleting_survey')%>";
  surveysI18n.enabling_survey = "<%= t('admin.surveys.index.enabling_survey')%>";
  surveysI18n.disabling_survey = "<%= t('admin.surveys.index.disabling_survey')%>";
  surveysI18n.previewBegin = "<%=t('admin.surveys.index.feedback_survey_begin')%>";
  surveysI18n.previewEnd = "<%=t('admin.surveys.index.feedback_survey_end')%>";
  surveysI18n.update = "<%=t('admin.surveys.index.update')%>";


  SurveyConstants = {
  rating:{
    "EXTREMELY_UNHAPPY":-103,
    "VERY_HAPPY":102,
    "HAPPY":101,
    "NEUTRAL":100,
    "UNHAPPY":-101,
    "VERY_UNHAPPY":-102,
    "EXTREMELY_HAPPY":103
  },
  notification:{
    "CLOSED_NOTIFICATION":3,
    "RESOLVED_NOTIFICATION":2,
    "ANY_EMAIL_RESPONSE":1,
    "SPECIFIC_EMAIL_RESPONSE":4
  },
  questions:{
    "LIMIT" : 10
  },
  limit:{
    "thanks_text" : 500,
    "scale":30,
    "title_text": 150
  }
}


  view = {"choiceValues":[{"id":"-103","text":"Strongly Disagree","className":"strongly-disagree"},
            {"id":"-102","text":"Some What Disagree","className":"some-what-disagree"},
            {"id":"-101","text":"Disagree","className":"disagree"},
            {"id":"100","text":"Neutral","className":"satisfaction-neutral"},
            {"id":"101","text":"Agree","className":"agree"},
            {"id":"102","text":"Some What Agree","className":"some-what-agree"},
            {"id":"103","text":"Strongly Agree","className":"strongly-agree"}],
    "action":"new","rating":{"title":" Customer Satisfaction Rating",
    "link_text":" Please tell us what you think of your support experience",
    "send_while":{"title":" Choose which emails have the satisfaction survey link",
    "elements":[{"value":"3","text":"EmailssentafteraticketisClosed."},
          {"value":"2","text":"EmailssentafteraticketisResolved."},
          {"value":"1","text":"Allrepliessenttocustomer."},
          {"value":"4","text":"Allowagentstoaddsurveylinkstospecificemails."}],
    "defaultValue":2}},"scale":{"keys":"[2, 3, 5, 7]","default":3,"click":"SurveyProtocol.content.scale.change(this)"},
    "choice":{"2":"[103, -103]","3":"[103, 100, -103]","5":"[103, 102, 100, -102, -103]","7":"[103, 102, 101, 100, -101, -102, -103]"},
    "thanks":{"title":"Thank you message","message":"Thank you for your valuable feedback.",
    "link":{"label":"Add a feedback survey","action":"SurveyQuestion.create()"}},
    "survey":{"elements":[{"type":"link","html":"SurveyList","click":"SurveyList.show"},
    {"type":"link","html":"Createnewsurvey","click":"SurveyQuestion.set.new"}]},
    "question":{"default_text":"Thank you for your valuable feedback."},
    "questions":{"action":{"value":"+ Add Question","click":"SurveyQuestion.add()"},
    "list":[{"label":"Areyousatisfiedwithourcustomersupportexperience?"}],"limit":10,"count":0,
    "choiceValues":[{"id":"-103","text":"StronglyDisagree","className":"strongly-disagree"},
            {"id":"100","text":"Neutral","className":"satisfaction-neutral"},
            {"id":"101","text":"Agree","className":"agree"},
            {"id":"102","text":"SomeWhatAgree","className":"some-what-agree"},
            {"id":"103","text":"StronglyAgree","className":"strongly-agree"}]},
    "can_comment":false,"feedback_response_text":""};


  survey_list = {"survey":{"active":1,"can_comment":1,"created_at":"2015-03-02T19:09:11+05:30",
                 "feedback_response_text":"","id":20,"link_text":" Please tell us what you think of your support experience",
                 "send_while":1,"thanks_text":"Thank you for your valuable feedback.",
                 "title_text":"test_survey123","updated_at":"2015-03-02T19:16:40+05:30",
                 "choices":[["Strongly Agree",103],["Neutral",100],["Strongly Disagree",-103]]}}

SurveyReportData = {
									  "reportsList": [[2, {"entity_id": 2, "category": "company", "name": "Test Account", "title": "survey.freshdesk-dev.com", "total": 5, "rating": {"0": 4, "-3": 1}}]],
									  "surveyReports": "[]",
									  "surveysList": [{"active": 0, "created_at": "2015-01-02T13:18:33+05:30", "id": 2, "rating": {"-3": 1, "3": 1, "0":1},
									  					"link_text": "Please tell us what you think of your support experience.", "title_text": "Default Survey", "choices": [["Agree", 3], ["Neutral", 0], ["Disagree", -3]], "survey_questions": []}, 
									  					{"active": 0, "created_at": "2015-01-02T14:42:44+05:30", "id": 3, "link_text": " Please tell us what you think of your support experience", 
									  					"title_text": "test", "choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]], 
									  					"survey_questions": [{"id": 1, "label": "q1","rating":1, "name": "cf_q1", "choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]]}, {"id": 3, "label": "q2", "name": "cf_q2", "choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]]}
									  					]}, 
									  					{"active": 1, "created_at": "2015-01-02T19:01:45+05:30", "id": 4,"rating": {"-3": 1, "3": 1, "0":1}, "link_text": " Please tell us what you think of your support experience", 
									  					"title_text": "ewrwerwer", "choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]], 
									  					"survey_questions": [{"id": 2, "label": "q1", "name": "cf_q1", "rating": 3, "choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]]}, {"id": 3, "label": "q2", "name": "cf_q2", "choices": [["Strongly Agree", 3], ["Neutral", 0], ["Strongly Disagree", -3]]}
									  					]}],
									  "agentsList": [{"created_at": "2015-01-02T13:18:26+05:30", "id": 2, "user": {"active": true, "address": null, "created_at": "2015-01-02T13:18:26+05:30", "deleted": false, "description": null, "email": "vasutha@freshdesk.com", "external_id": null, "fb_profile_id": null, "helpdesk_agent": true, "id": 3, "job_title": null, "language": "en", "mobile": null, "name": "Support", "phone": null, "time_zone": "Chennai", "twitter_id": null, "updated_at": "2015-01-03T11:14:17+05:30"}}],
									  "groupsList": [{"created_at": "2015-01-02T13:18:28+05:30", "description": "Product Management group", "id": 4, "name": "Product Management", "agents": []}, {"created_at": "2015-01-02T13:18:28+05:30", "description": "Members of the QA team belong to this group", "id": 5, "name": "QA", "agents": []}, {"created_at": "2015-01-02T13:18:28+05:30", "description": "People in the Sales team are members of this group", "id": 6, "name": "Sales", "agents": []}],
									  "survey_report_date_range": "4 Dec, 2014 - 3 Jan, 2015\t",
									  "customerRatings": {
									    "0": "neutral",
									    "1": "happy",
									    "2": "very_happy",
									    "3": "extremely_happy",
									    "-1": "unhappy",
									    "-2": "very_unhappy",
									    "-3": "extremely_unhappy"
									  },
									  "link_text" :" Please tell us what you think of your support experience",
									  "customerRatingsColor": {
									  },
									  "requestsCount": 2,
									  "type" : {"question":2,"rating":1},
									  "questionsResult": {
								   			"cf_how_would_you_rate_your_overall_satisfaction_for_the_resolution_provided_by_the_agent":
									   		{"rating":[{"rating":-3,"total":2},{"rating":0,"total":4},{"rating":3,"total":2}],"default":true},
									   		"cf_q1":
									   		{"rating":[{"rating":-3,"total":2},{"rating":0,"total":6}],"default":false},
									   		"cf_are_you_satisfied_with_our_replies":
									   		{"rating":[{"rating":-3,"total":2},{"rating":0,"total":3},{"rating":3,"total":3}],"default":false}
									   	},
									  "defaultAllValues":{"agent":"a","group":"g","rating":"r"},
									  "groupWiseReport":{
									  	"cf_how_would_you_rate_your_overall_satisfaction_for_the_resolution_provided_by_the_agent":
									  	{"5":{"id":5,"name":"QA","total":4,"rating":{"-3":2,"0":2}},"4":{"id":4,"name":"Product Management","total":1,"rating":{"3":1}}},
									  	"cf_q1":
									  	{"5":{"id":5,"name":"QA","total":4,"rating":{"-3":1,"0":3}},"4":{"id":4,"name":"Product Management","total":1,"rating":{"0":1}}},
									  	"cf_are_you_satisfied_with_our_replies":
									  	{"4":{"id":4,"name":"Product Management","total":1,"rating":{"-3":1}},"5":{"id":5,"name":"QA","total":4,"rating":{"-3":1,"0":2,"3":1}}}},
									  "agent_wise_report": {
									  	"cf_how_would_you_rate_your_overall_satisfaction_for_the_resolution_provided_by_the_agent":
									  	{"3":{"id":3,"name":"Support","total":8,"rating":{"-3":2,"0":4,"3":2}}},
									  	"cf_q1":
									  	{"3":{"id":3,"name":"Support","total":8,"rating":{"-3":2,"0":6}}},
									  	"cf_are_you_satisfied_with_our_replies":
									  	{"3":{"id":3,"name":"Support","total":8,"rating":{"-3":2,"0":3,"3":3}}}}
							}

SurveyI18N = {};
SurveyI18N.all = "<%= t('reports.survey_reports.main.all') %>";
SurveyI18N.time_period = "<%= t('reports.survey_reports.main.time_period') %>";
SurveyI18N.group = "<%= t('reports.survey_reports.main.group') %>";
SurveyI18N.agent = "<%= t('reports.survey_reports.main.agent') %>";
SurveyI18N.overview = "<%= t('reports.survey_reports.main.overview') %>";
SurveyI18N.responses = "<%= t('reports.survey_reports.main.responses') %>";		
SurveyI18N.response_to = "<%= t('reports.survey_reports.main.response_to') %>";
SurveyI18N.rating = "<%= t('reports.survey_reports.main.rating') %>";
SurveyI18N.question = "<%= t('reports.survey_reports.main.question') %>";
SurveyI18N.positive = "<%= t('reports.survey_reports.main.positive') %>";
SurveyI18N.neutral = "<%= t('reports.survey_reports.main.neutral') %>";
SurveyI18N.negative = "<%= t('reports.survey_reports.main.negative') %>";
SurveyI18N.answered = "<%= t('reports.survey_reports.main.answered') %>";
SurveyI18N.unanswered = "<%= t('reports.survey_reports.main.unanswered') %>";
SurveyI18N.total_responses = "<%= t('reports.survey_reports.main.total_responses') %>";
SurveyI18N.preparing_chart_for = "<%= t('reports.survey_reports.main.preparing_chart_for') %>";
SurveyI18N.loading_chart = "<%=t('reports.survey_reports.main.loading_chart')%>";
SurveyI18N.month_names = "<%=t('date.abbr_month_names').to_json.html_safe%>";
SurveyI18N.no_remarks = "<%= t('reports.survey_reports.main.no_remarks') %>";
SurveyI18N.loading_remarks = "<%= t('reports.survey_reports.main.loading_remarks') %>";
SurveyI18N.fetching_responses = "<%= t('reports.survey_reports.main.fetching_responses') %>";
SurveyI18N.no_overview = "<%= t('reports.survey_reports.main.no_overview') %>";

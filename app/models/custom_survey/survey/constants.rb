class CustomSurvey::Survey < ActiveRecord::Base
  ANY_EMAIL_RESPONSE = 1
  RESOLVED_NOTIFICATION = 2
  CLOSED_NOTIFICATION = 3
  SPECIFIC_EMAIL_RESPONSE = 4
  PLACE_HOLDER = 5

  #customer rating
  EXTREMELY_HAPPY = 103
  VERY_HAPPY = 102
  HAPPY = 101
  NEUTRAL = 100
  UNHAPPY = -101
  VERY_UNHAPPY = -102
  EXTREMELY_UNHAPPY = -103

  QUESTIONS_LIMIT = 10
  SURVEYS_LIMIT = 10
  TITLE_TEXT_LIMIT =150
  LINK_TEXT_LIMIT = 500


  CUSTOMER_RATINGS_MAP = [
    [EXTREMELY_HAPPY,'extremely_happy', '#4e8d00','#e6efdd','strongly-agree'],
    [VERY_HAPPY,'very_happy','#6bb436','#ebf4e3','some-what-agree'],
    [HAPPY,'happy','#a9d340','#f3f9e5','agree'],
    [NEUTRAL,'neutral','#f1db16','#fdfae2','satisfaction-neutral'],
    [UNHAPPY,'unhappy','#ffc400','#fff7e0','disagree'],
    [VERY_UNHAPPY,'very_unhappy','#ff8c00','#ffefdf','some-what-disagree'],
    [EXTREMELY_UNHAPPY,'extremely_unhappy','#e7340f','#fce3e0','strongly-disagree']
  ]

  CUSTOMER_RATINGS = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[0], i[1]] }.flatten]
  CUSTOMER_RATINGS_COLOR = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[0], i[2]] }.flatten]
  CUSTOMER_RATINGS_TEXT_BGCOLOR = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[0], i[3]] }.flatten]
  CUSTOMER_RATINGS_STYLE = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[0], i[4]] }.flatten]

  CUSTOMER_RATINGS_BY_TOKEN = CUSTOMER_RATINGS.invert

  FILTER_BY_ARR = [["By Agents" , :agent] , ["By Groups", :group] , ["Overall Helpdesk" , :company]]

  AGENT = "agent"
  GROUP = "group"
  OVERALL = "company"
  QUESTION = "question"

  LIST = "list"

  SAMPLE_TICKET_MSG = I18n.t('ticket_fields.survey_preview_ticket_msg')
end
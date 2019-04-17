class CustomSurvey::Survey < ActiveRecord::Base

  ANY_EMAIL_RESPONSE      = 1
  RESOLVED_NOTIFICATION   = 2
  CLOSED_NOTIFICATION     = 3
  SPECIFIC_EMAIL_RESPONSE = 4
  PLACE_HOLDER            = 5

  QUESTIONS_LIMIT   = 10
  SURVEYS_LIMIT     = 10
  TITLE_TEXT_LIMIT  = 150
  LINK_TEXT_LIMIT   = 500

  SEND_WHILE_MAPPING = {
    1 => :any_email_response,
    2 => :resolved_notification,
    3 => :closed_notification,
    4 => :specific_email_response,
    5 => :place_holder
  }.freeze

  CUSTOMER_RATINGS_MAP = [
    [:EXTREMELY_HAPPY,    103, 'extremely_happy',    '#4e8d00', '#e6efdd', 'strongly-agree'],
    [:VERY_HAPPY,         102, 'very_happy',         '#6bb436', '#ebf4e3', 'some-what-agree'],
    [:HAPPY,              101, 'happy',              '#a9d340', '#f3f9e5', 'agree'],
    [:NEUTRAL,            100, 'neutral',            '#f1db16', '#fdfae2', 'satisfaction-neutral'],
    [:UNHAPPY,           -101, 'unhappy',            '#ffc400', '#fff7e0', 'disagree'],
    [:VERY_UNHAPPY,      -102, 'very_unhappy',       '#ff8c00', '#ffefdf', 'some-what-disagree'],
    [:EXTREMELY_UNHAPPY, -103, 'extremely_unhappy',  '#e7340f', '#fce3e0', 'strongly-disagree']
  ]

  CUSTOMER_RATINGS_MAP.each do |i|
    const_set i[0], i[1]
  end

  CUSTOMER_RATINGS        = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[1], i[2]] }.flatten]
  CUSTOMER_RATINGS_COLOR  = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[1], i[3]] }.flatten]
  CUSTOMER_RATINGS_TEXT_BGCOLOR = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[1], i[4]] }.flatten]
  CUSTOMER_RATINGS_STYLE  = Hash[*CUSTOMER_RATINGS_MAP.map { |i| [i[1], i[5]] }.flatten]
  CUSTOMER_RATINGS_FACE_VALUE = CUSTOMER_RATINGS_MAP.map { |i| i[1] }.flatten

  CUSTOMER_RATINGS_BY_TOKEN = CUSTOMER_RATINGS.invert

  FILTER_BY_ARR = [["By Agents" , :agent] , ["By Groups", :group] , ["Overall Helpdesk" , :company]]

  AGENT     = "agent"
  GROUP     = "group"
  OVERALL   = "company"
  QUESTION  = "question"

  LIST = "list"

  SAMPLE_TICKET_MSG = I18n.t('ticket_fields.survey_preview_ticket_msg')

  CLASSIC_TO_CUSTOM_RATING = {
    "happy"   => "extremely_happy",
    "neutral" => "neutral",
    "unhappy" => "extremely_unhappy"
  }
end

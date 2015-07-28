class CustomSurvey::SurveyHandle < ActiveRecord::Base
  NOTIFICATION_VS_SEND_WHILE = {
    EmailNotification::TICKET_RESOLVED => CustomSurvey::Survey::RESOLVED_NOTIFICATION,
    EmailNotification::TICKET_CLOSED => CustomSurvey::Survey::CLOSED_NOTIFICATION,
    EmailNotification::PREVIEW_EMAIL_VERIFICATION => CustomSurvey::Survey::ANY_EMAIL_RESPONSE
  }
end
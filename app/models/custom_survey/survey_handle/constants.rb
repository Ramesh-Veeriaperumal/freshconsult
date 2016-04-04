class CustomSurvey::SurveyHandle < ActiveRecord::Base
  NOTIFICATION_VS_SEND_WHILE = {
    EmailNotification::TICKET_RESOLVED => CustomSurvey::Survey::RESOLVED_NOTIFICATION,
    EmailNotification::TICKET_CLOSED => CustomSurvey::Survey::CLOSED_NOTIFICATION
  }
end
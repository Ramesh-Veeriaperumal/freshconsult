class CustomSurvey::SurveyHandle < ActiveRecord::Base
  NOTIFICATION_VS_SEND_WHILE = {
    EmailNotification::TICKET_RESOLVED => CustomSurvey::Survey::RESOLVED_NOTIFICATION,
    EmailNotification::TICKET_CLOSED => CustomSurvey::Survey::CLOSED_NOTIFICATION
  }
  NEW_VIA_PORTAL = 'new_via_portal'.freeze
  DESTROY_HANDLE_DELAY_INTERVAL = 20
end
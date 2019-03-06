module CentralConstants
  # Note: Please follow this convention.
  # In case of addition(non-breaking changes on consumer) Bump the minor version. update from 0.0 to 0.1
  # In case of any breaking changes, bump the majore version, update from 0.0 to 1.0
  MODEL_PAYLOAD_VERSION = {
    'Account' => '1.0',
    'Helpdesk::Ticket' => '2.0',
    'Helpdesk::Note' => '0.0',
    'Solution::Category' => '0.0',
    'Solution::Folder' => '0.0',
    'Solution::Article' => '0.0',
    'Bot::FeedbackMapping' => '0.0',
    'User' => '0.0',
    'Company' => '0.0',
    'Subscription' => '1.0',
    'Agent' => '1.0',
    'VaRule' => '0.0',
    'Group' => '2.0',
    'Post' => '0.0',
    'Helpdesk::TimeSheet' => '1.0',
    'DashboardAnnouncement' => '0.0',
    'Social::TwitterHandle' => '0.0',
    'Social::TwitterStream' => '0.0',
    'Integrations::InstalledApplication' => '0.0',
    'Social::FacebookPage' => '0.0',
    'Product' => '0.0',
    'Bot::Response' => '0.0',
    'Helpdesk::TicketField' => '0.0',
    'AgentGroup' => '0.0',
    'Helpdesk::Tag' => '0.0',
    'Helpdesk::TagUse' => '0.0',
    'Helpdesk::TicketStatus' => '0.0',
    'Helpdesk::PicklistValue' => '0.0',
    'Survey' => '0.0',
    'SurveyHandle' => '0.0',
    'SurveyResult' => '0.0',
    'CustomSurvey::Survey' => '0.0',
    'CustomSurvey::SurveyQuestion' => '0.0',
    'CustomSurvey::SurveyQuestionChoice' => '0.0',
    'CustomSurvey::SurveyHandle' => '0.0',
    'CustomSurvey::SurveyResult' => '0.0'
  }
end

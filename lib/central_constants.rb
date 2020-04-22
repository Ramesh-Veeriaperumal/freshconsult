module CentralConstants
  # Note: Please follow this convention.
  # In case of addition(non-breaking changes on consumer) Bump the minor version. update from 0.0 to 0.1
  # In case of any breaking changes, bump the majore version, update from 0.0 to 1.0
  MODEL_PAYLOAD_VERSION = {
    'Account' => '1.3',
    'Helpdesk::Ticket' => '2.13',
    'Helpdesk::Note' => '0.8',
    'Solution::Category' => '0.1',
    'Solution::Folder' => '0.1',
    'Solution::Article' => '0.2',
    'Bot::FeedbackMapping' => '0.1',
    'User' => '0.4',
    'Company' => '1.2',
    'Subscription' => '1.2',
    'Agent' => '2.2',
    'VaRule' => '0.2',
    'Group' => '3.1',
    'Post' => '0.1',
    'Helpdesk::TimeSheet' => '1.3',
    'DashboardAnnouncement' => '0.1',
    'Social::TwitterHandle' => '0.1',
    'Social::TwitterStream' => '0.1',
    'Integrations::InstalledApplication' => '0.1',
    'Social::FacebookPage' => '0.3',
    'Social::FacebookStream' => '0.1',
    'Product' => '0.1',
    'Helpdesk::TicketField' => '1.1',
    'AgentGroup' => '0.1',
    'Helpdesk::Tag' => '0.1',
    'Helpdesk::TagUse' => '0.1',
    'Helpdesk::TicketStatus' => '0.1',
    'Helpdesk::PicklistValue' => '0.1',
    'Survey' => '0.1',
    'SurveyHandle' => '0.1',
    'SurveyResult' => '0.1',
    'CustomSurvey::Survey' => '0.1',
    'CustomSurvey::SurveyQuestion' => '0.1',
    'CustomSurvey::SurveyQuestionChoice' => '0.1',
    'CustomSurvey::SurveyHandle' => '0.1',
    'CustomSurvey::SurveyResult' => '0.1',
    'ContactField' => '0.1',
    'ContactFieldChoice' => '0.1',
    'CompanyField' => '0.1',
    'CompanyFieldChoice' => '0.1',
    'Freshcaller::Account' => '0.2',
    'Freshchat::Account' => '0.1',
    'Admin::CannedResponses::Folder' => '0.1',
    'Admin::CannedResponses::Response' => '0.1',
    'ConversionMetric' => '0.1',
    'Portal' => '0.1'
  }

  # To avoid duplicate central event of associated models(user_companies) with model(user) as exchange payload,
  # include attr_accessor(associated_model_changes) in model, it will skip associated model central events for a certain model action.
  SKIP_EVENT = [
    # [model, model_payload, associated_model, associated_model_changed]
    ['User', :contact_create, :user_companies, :user_companies_updated],
    ['User', :contact_create, :user_emails, :user_emails_updated]
  ].freeze

  # { "User" => { 
  #              :contact_create => { :user_companies => :user_companies_updated, :user_emails => :user_emails_updated } 
  # } }
  SKIP_EVENT_BY_EXCHANGE_KLASS = SKIP_EVENT.each_with_object({}) { |arr, hash| hash[arr[0]] = (hash[arr[0]] || {}).merge(arr[1] => ((hash[arr[0]] && hash[arr[0]][arr[1]]) || {}).merge(arr[2] => arr[3])) }.freeze
end

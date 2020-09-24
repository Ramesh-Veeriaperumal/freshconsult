module CentralConstants
  # Note: Please follow this convention.
  # In case of addition(non-breaking changes on consumer) Bump the minor version. update from 0.0 to 0.1
  # In case of any breaking changes, bump the majore version, update from 0.0 to 1.0
  MODEL_PAYLOAD_VERSION = {
    'Account' => '1.5',
    'Helpdesk::Ticket' => '2.18',
    'Helpdesk::Note' => '1.1',
    'Solution::Category' => '0.3',
    'Solution::Folder' => '0.4',
    'Solution::Article' => '0.5',
    'ArticleTicket' => '0.2',
    'PortalSolutionCategory' => '0.2',
    'Bot::FeedbackMapping' => '0.2',
    'User' => '0.5',
    'Company' => '1.3',
    'Subscription' => '1.3',
    'Agent' => '2.4',
    'VaRule' => '0.3',
    'Group' => '3.2',
    'Post' => '0.2',
    'Helpdesk::TimeSheet' => '1.6',
    'DashboardAnnouncement' => '0.2',
    'Social::TwitterHandle' => '0.2',
    'Social::TwitterStream' => '0.2',
    'Integrations::InstalledApplication' => '0.2',
    'Social::FacebookPage' => '0.4',
    'Social::FacebookStream' => '0.2',
    'Product' => '0.2',
    'Helpdesk::TicketField' => '1.3',
    'AgentGroup' => '0.2',
    'Helpdesk::Tag' => '0.2',
    'Helpdesk::TagUse' => '0.2',
    'Helpdesk::TicketStatus' => '0.2',
    'Helpdesk::PicklistValue' => '0.2',
    'Survey' => '0.2',
    'SurveyHandle' => '0.2',
    'SurveyResult' => '0.2',
    'CustomSurvey::Survey' => '0.2',
    'CustomSurvey::SurveyQuestion' => '0.2',
    'CustomSurvey::SurveyQuestionChoice' => '0.2',
    'CustomSurvey::SurveyHandle' => '0.2',
    'CustomSurvey::SurveyResult' => '0.2',
    'ContactField' => '0.2',
    'ContactFieldChoice' => '0.2',
    'CompanyField' => '0.2',
    'CompanyFieldChoice' => '0.2',
    'Freshcaller::Account' => '0.3',
    'Freshchat::Account' => '0.2',
    'Admin::CannedResponses::Folder' => '0.2',
    'Admin::CannedResponses::Response' => '0.2',
    'ConversionMetric' => '0.2',
    'Portal' => '0.3',
    'HelpWidget' => '0.2',
    'Helpdesk::Filters::CustomTicketFilter' => '0.2',
    'Helpdesk::Source' => '0.2',
    'Helpdesk::ArchiveTicket' => '1.2'
  }

  HYPERTRAIL_VERSION = '0.0.1'.freeze
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

  # To skip event without valid properties in model changes but has below properties
  INVALID_MODEL_CHANGES = [:updated_at].freeze
end

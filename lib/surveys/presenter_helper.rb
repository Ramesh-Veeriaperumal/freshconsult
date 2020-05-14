module Surveys::PresenterHelper
  extend ActiveSupport::Concern
  included do
    after_commit :backup_changes
  end

  def backup_changes
    @model_changes ||= {}
    @model_changes.merge!(self.previous_changes.clone.to_hash)
    @model_changes.symbolize_keys!
  end

  def deleted_survey_model_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def model_changes_for_central
    @model_changes
  end

  def central_publish_worker_class
    'CentralPublishWorker::SurveyWorker'
  end

  def event_info(_action)
    { ip_address: Thread.current[:current_ip] }
  end

  def send_while_hash
    send_while = self.respond_to?(:send_while) ? self.safe_send('send_while') : self.safe_send('sent_while')
    {
      id: send_while,
      type: Survey::SEND_WHILE_MAPPING[send_while].to_s
    }
  end

end

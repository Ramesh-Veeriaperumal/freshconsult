module MixpanelWrapper
  class << self
    def send_to_mixpanel(model_class, data = {})
      return unless Account.current
      msg = {:account_id => Account.current.id, :domain => Account.current.full_domain, :model => model_class.underscore.gsub(/\//, '_'),
       :options => data }
      MixpanelWorker.perform_async(msg) if check_default_events(model_class)
    end

    def check_default_events(model_class_name)
        (model_class_name == "Account") or (Account.current.created_at < 2.minutes.ago)
    end
  end
end
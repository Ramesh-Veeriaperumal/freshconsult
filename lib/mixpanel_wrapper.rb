module MixpanelWrapper

  def send_to_mixpanel(model_class, data = {})
    return unless Account.current
    msg = { :domain => Account.current.full_domain, :model => model_class.underscore.gsub(/\//, '_'),
     :options => data }
    MixpanelWorker.perform_async(msg)
  end
end
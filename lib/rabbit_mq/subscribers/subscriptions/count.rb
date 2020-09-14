module RabbitMq::Subscribers::Subscriptions::Count

  def mq_count_subscription_valid(action, model)
    true
  end

  def mq_count_subscriber_properties(action)
    {}
  end

  def mq_count_subscription_properties(action)
    subscription_properties(self.ticket)
  end

  private

    def subscription_properties(model_object)
      {
        :document_id  => model_object.id,
        :klass_name   => model_object.class.to_s,
        :action       => "update", #always its update for count cluster, even if watcher is removed
        :account_id   => Account.current.try(:id) || model_object.account_id
      }
    end

end
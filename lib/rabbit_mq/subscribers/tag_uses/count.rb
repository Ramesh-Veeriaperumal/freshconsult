module RabbitMq::Subscribers::TagUses::Count

  def mq_count_valid(action, model)
    Account.current.features?(:countv2_writes) && valid_count_model?(model)
  end

  def mq_count_tag_use_properties(action)
    destroy_action?(action) ? {} : properties(self.taggable, action) 
  end

  def mq_count_subscriber_properties(action)
    {}
  end

  private

    def valid_count_model?(model)
      ['tag_use'].include?(model)
    end

    def properties(model_object, action)
      {
        :document_id  => model_object.id,
        :klass_name   => model_object.class.to_s,
        :action       => action,
        :account_id   => Account.current.try(:id) || model_object.account_id
      }
    end

end
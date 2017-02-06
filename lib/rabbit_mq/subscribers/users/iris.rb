module RabbitMq::Subscribers::Users::Iris
  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [:name, :job_title, :email, :phone, :mobile, :customer_id, 
                            :twitter_id, :address, :time_zone, :language, :tag_names, 
                            :description, :deleted, :active, :blocked, :helpdesk_agent,
                            :whitelisted, :fb_profile_id, :user_role]

  def mq_iris_user_properties(action)
    to_rmq_json(iris_keys, action)
  end
  
  def mq_iris_user_email_properties(action)
    self.user.to_rmq_json(iris_keys, action)
  end

  def mq_iris_subscriber_properties(action)
    {}
  end

  def mq_iris_valid(action, model)
    if self.is_a?(UserEmail)
      iris_user_email_changes.any? || destroy_action?(action)
    else
      iris_user_changes(action).any?
    end
  end

  private

    def iris_user_changes(action)
      create_action?(action) ? iris_user_create_changes : iris_user_update_changes
    end

    def iris_user_update_changes
      @all_changes ? @all_changes.dup.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) || ff_fields.include?(k.to_s) } : {}
    end

    def iris_valid_model?(model)
      ["user", "user_email"].include?(model)
    end

    def iris_user_create_changes
       changes = self.previous_changes.dup
       changes.merge!(flexifield.previous_changes.dup) if flexifield.previous_changes.present?
       changes.dup.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k.to_sym) || ff_fields.include?(k) }
    end

    def iris_user_email_changes
      self.previous_changes.dup.select{|k,v| ["email"].include?(k)}
    end

    def iris_keys
      IRIS_USER_KEYS
    end

end
module RabbitMq::Subscribers::Accounts::Collaboration
  def mq_collaboration_account_properties(action)
    { id: id }
  end

  def mq_collaboration_subscriber_properties(action)
    update_action?(action) ? account_data : {}
  end

  def mq_collaboration_valid(action, model)
    valid_collab_model?(model) && (destroy_action?(action) || (Account.current.collaboration_enabled? && update_action?(action) && valid_changes.present?))
  end

  private

    def valid_collab_model?(model)
      ['account'].include?(model)
    end

    def account_data
      protocol = Rails.env.development? ? 'http://' : 'https://'
      {
        domain_url: "#{protocol}#{Account.current.full_domain}",
        access_token: account_admin.single_access_token.presence,
        collab_feature: Account.current.collaboration_enabled?
      }
    end

    def valid_changes
      previous_changes.dup.select { |k, v| ['full_domain'].include?(k) }
    end

    def account_admin
      Account.current.account_managers.first
    end
end

class OmniChannelUpgrade::SyncAgents < BaseWorker
  sidekiq_options queue: :sync_omni_agents, retry: 5, backtrace: true, failures: :exhausted

  FRESHCALLER = 'freshcaller'.freeze

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    performer_id = args[:performer_id]
    product_name = args[:product_name]
    performer = account.agents.find(performer_id)
    performer.user.make_current
    create_agents_in_omni_account(account, performer, product_name)
  rescue StandardError => e
    Rails.logger.error "Error while syncing agents to omni account for product #{product_name} Account ID: #{account.id} Exception: #{e.message} :: #{e.backtrace[0..20].inspect}"
    NewRelic::Agent.notice_error(e, account_id: Account.current.id, args: args)
    raise e
  ensure
    User.reset_current_user
  end

  private

    def create_agents_in_omni_account(account, performer, product_name)
      agents = account.full_time_support_agents
      agents.each do |agent|
        next if agent.id == performer.id

        safe_send("enable_#{product_name.downcase}_agent", agent)
      end
    end

    def enable_freshcaller_agent(agent)
      agent.freshcaller_enabled = true
      agent.save!
      raise 'Freshcaller agent sync failed' unless agent.agent_freshcaller_enabled?
    end

    def enable_freshchat_agent(agent)
      agent.freshchat_enabled = true
      agent.save!
      raise 'Freshchat agent sync failed' unless agent.agent_freshchat_enabled?
    end
end

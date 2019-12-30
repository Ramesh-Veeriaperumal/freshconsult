module Freshcaller
  class UpdateAgentsWorker < BaseWorker
    attr_accessor :agents_to_add, :agents_to_remove

    sidekiq_options queue: :freshcaller_update_agents, retry: 0, failures: :exhausted

    def perform(params)
      params.symbolize_keys!
      @current_account = ::Account.current
      return unless @current_account.freshcaller_enabled?

      fetch_agent_ids(params[:agent_user_ids])
      add_or_remove_agents
    rescue StandardError => e
      Rails.logger.error "Freshcaller UpdateAgentsWorker exception :: #{params[:account_id]} #{e.message} #{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, description: "Error on UpdateAgentsWorker for account : #{params[:account_id]} \n#{e.message}\n#{e.backtrace.join("\n\t")}")
    end

    private

      include Freshcaller::AgentUtil

      def fetch_agent_ids(new_ids)
        existing_ids = freshcaller_agents.map { |fagent| fagent.user && fagent.user.id }.compact
        @agents_to_add = new_ids - existing_ids
        @agents_to_remove = existing_ids - new_ids
      end

      def freshcaller_agents
        @current_account.freshcaller_agents.where(fc_enabled: true).preload(:user)
      end

      def add_or_remove_agents
        agents.each do |agent|
          agent.freshcaller_enabled = agents_to_add.include?(agent.user_id)
          create_update_fc_agent(agent)
        end
      end

      def agents
        @current_account.agents.where(user_id: agents_to_add + agents_to_remove).preload(:freshcaller_agent)
      end
  end
end

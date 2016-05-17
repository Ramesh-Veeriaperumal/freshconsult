class Livechat::Sync

  include Chat::Constants

  #This method is called directly from controller
  def sync_data_to_livechat(siteId)
    # data_methods = [ 'roles', 'agents', 'groups', 'enable_privileges' ]
    data_methods = [ 'agents', 'groups' ]
    send(data_methods.shift, data_methods, siteId)
  end

  #This method is called from frontend
  def roles next_methods, siteId
    sidekiq_batch(siteId, next_methods).jobs do
      current_account.roles.each do |role|
        job = {:worker_method => "create_role", :siteId => siteId,
                :name => role.name, :default_role => role.default_role, :external_id => role.id,
                :privilege_list => role.chat_privileges.map(&:to_s)}
        LivechatWorker.perform_async(job)
      end
    end
  end

  #This method is called from sidekiq backend callbacks
  def agents next_methods, siteId
    sidekiq_batch(siteId, next_methods).jobs do
      current_account.agents.includes({user: :roles}).each do |agent|
        c = {
          :name=>agent.user.name,
          :agent_id=>agent.user.id,
          :site_id =>siteId,
          :roles => agent.user.roles.map(&:id),
          :scope => SCOPE_TOKENS_BY_KEY[agent.ticket_permission]
        }
        job = {:worker_method =>"create_agent",
                          :siteId => siteId, :agent_data => [c].to_json}
        LivechatWorker.perform_async(job)
      end
    end
  end

  #This method is called from sidekiq backend callbacks
  def groups next_methods, siteId
    sidekiq_batch(siteId, next_methods).jobs do
      current_account.groups_from_cache.each do |group|
        group_agents = []
        group.agent_groups.each{ |agentGroup| group_agents << {site_id: siteId, group_id: group.id, agent_id: agentGroup.user_id}}
        job = {:worker_method => "create_group",
                          :siteId => siteId, :group_id => group.id, group_agents: group_agents.to_json,
                          :name => group.name, :business_calendar_id => group.business_calendar_id}
        LivechatWorker.perform_async(job)
      end
    end

  end

  #This method is called from sidekiq backend callbacks
  def enable_privileges next_methods, siteId
    LivechatWorker.perform_async({"worker_method" => 'enable_prirvilege_check',"siteId" => siteId})
  end

  #This method is called from sidekiq backend callbacks
  def on_success(status, options)
    next_methods = options["next_methods"]
    Livechat::Sync.new.send(next_methods.shift, next_methods, options['siteId']) unless next_methods.blank?
  end

  def sidekiq_batch(siteId, next_methods)
    batch = Sidekiq::Batch.new
    batch.on(:success, Livechat::Sync, 'bid' => batch.bid, 'siteId' => siteId, :next_methods => next_methods)
    batch
  end

  def current_account
    Account.current
  end
end

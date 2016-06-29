class Livechat::Sync

  include Chat::Constants

  #This method is called directly from controller
  def sync_data_to_livechat(siteId)
    # data_methods = [ 'roles', 'agents', 'groups', 'enable_privileges' ]
    data_methods = [ 'agents', 'groups' ]
    send(data_methods.shift, data_methods, siteId)
  end

  def sync_account_state args
    options = { :worker_method => 'update_site', :attributes => args }
    set_current_account_user_and_process_next options
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
    set_current_account_user_and_process_next options
  end

  def sidekiq_batch(siteId, next_methods)
    batch = Sidekiq::Batch.new
    batch.on(:success, Livechat::Sync, 'bid' => batch.bid, 
              'siteId' => siteId, :next_methods => next_methods, 
              :account_id => ::Account.current.id, :current_user_id => ::User.current.id)
    batch
  end

  def current_account
    ::Account.current
  end

  def current_user
    ::User.current
  end

  def set_current_account_user_and_process_next options={}
    next_methods = options["next_methods"]
    worker_method = options[:worker_method]
    account_id = current_account.present? ? current_account.id : options['account_id']
    if account_id && (next_methods.present? || worker_method.present?) 
      user_id = current_user.present? ? current_user.id : options['current_user_id'].present? ? options['current_user_id'] : nil;
      Sharding.select_shard_of(account_id) do
        account = ::Account.find(account_id)
        account.make_current
        user = account.users.find_by_id(user_id) if user_id.present?
        user = account.users.find_by_email(account.admin_email) if !user.present?
        if user.present?
          user.make_current
          unless next_methods.blank?
            send(next_methods.shift, next_methods, options['siteId'])
          else
            LivechatWorker.perform_async({ :worker_method => worker_method, :attributes => options[:attributes]})
          end
        end
        Account.reset_current_account
        User.reset_current_user
      end
    end
  end

end

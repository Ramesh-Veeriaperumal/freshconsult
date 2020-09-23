module Freshfone::Queue
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  BRIDGE_STATUS = ["redirected", "bridged"]

	def enqueue_caller
    twiml = Twilio::TwiML::Response.new do |r|
      current_number.read_queue_message(r)
      r.Gather :action => "#{host}/freshfone/queue/quit_queue_on_voicemail", :numDigits => '1' do |g|
        read_queue_position_message(g) if current_number.queue_position_preference
        (current_number.wait_message.present? && current_number.wait_message.message_url.present?) ? 
        current_number.play_wait_message(g) : play_default_music(g)
      end
    end
    render :xml => twiml.text
  end

  def bridge_queued_call(agent = nil)
    @available_agent ||= (agent or default_client).to_s # if @available_agent.blank?
    Rails.logger.info "Bridge Queued Call :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    @priority_call = nil
    if queued_members.list.any?
      check_for_priority_calls
      @priority_call ? bridge_priority_call : bridge_normal_call
    end
  end

  def bridge_priority_call
    Rails.logger.info "Priority Dequeue :: Account :: #{current_account.id}  :: Agent :: #{@available_agent}"
    begin
      member = queued_members.get(@priority_call)
      Rails.logger.info "Priority Dequeue :: Account :: #{current_account.id} :: CallSid :: #{@priority_call}"
      member.update(:url => "#{host}/freshfone/queue/dequeue?client=#{@available_agent}")
    rescue Twilio::REST::RequestError => e
      Rails.logger.error "Error trying to dequeue Priority call: #{e.message}"
      agent_hunted_call ? remove_call_sid_from_agent_queue :
        remove_call_sid_from_group_queue
      bridge_queued_call
    end
  end

  def bridge_normal_call
    Rails.logger.info "Simple Dequeue :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    simple_queue_call = default_queue_call
    if simple_queue_call
      member = queued_members.get(simple_queue_call)
      begin
        Rails.logger.info "Simple Dequeue :: Account :: #{current_account.id} :: CallSid :: #{simple_queue_call}"
        member.update(:url => "#{host}/freshfone/queue/dequeue")
      rescue Twilio::REST::RequestError => e
        Rails.logger.error "Error trying to dequeue call: #{e.message}"
        remove_call_sid_from_default_queue
        bridge_queued_call
      end
    end
  end

  def remove_call_sid_from_default_queue
    Rails.logger.info "Simple Queue Removal :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    queued_calls = get_key(default_queue_key)
    if queued_calls
      calls = JSON.parse(queued_calls)
      Rails.logger.info "Simple Queue Before Removal :: Account :: #{current_account.id} :: Key :: #{default_queue_key} :: Value :: #{calls.inspect}"
      calls.delete(calls.first)
      Rails.logger.info "Simple Queue After Removal :: Account :: #{current_account.id} :: Key :: #{default_queue_key} :: Value :: #{calls.inspect}"
      set_key(default_queue_key, calls.to_json)
    end
  end

  def remove_call_sid_from_agent_queue
    Rails.logger.info "Agent Queue Removal :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    agent_queue = get_key(agent_queue_key)
    if agent_queue
      calls = JSON.parse(agent_queue)
      Rails.logger.info "Agent Queue Before Removal :: Account :: #{current_account.id} :: Key :: #{agent_queue_key} :: Value :: #{calls.inspect}"
      if calls.keys.include? @available_agent
        hunted_agent_calls = calls[@available_agent]
        hunted_agent_calls.delete(hunted_agent_calls.first)
        calls[@available_agent] = hunted_agent_calls
      end
      Rails.logger.info "Agent Queue After Removal :: Account :: #{current_account.id} :: Key :: #{agent_queue_key} :: Value :: #{calls.inspect}"
      set_key(agent_queue_key, calls.to_json)
    end
  end

  def remove_call_sid_from_group_queue
    Rails.logger.info "Group Queue Removal :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    group_queue = get_key(group_queue_key)
    agent = current_account.users.technicians.find_by_id(@available_agent)
    agent_groups = agent.agent_groups.collect{|ag| ag.group_id}
    if group_queue
      group_calls = JSON.parse(group_queue)
      Rails.logger.info "Group Queue Before Removal :: Account :: #{current_account.id} :: Key :: #{group_queue_key} :: Value :: #{group_calls.inspect}"
      hunted_group = group_calls.keys.select{|group| agent_groups.include? group.to_i }.first
      hunted_group_calls = group_calls[hunted_group]
      hunted_group_calls.delete(hunted_group_calls.first)
      group_calls[hunted_group] = hunted_group_calls
      Rails.logger.info "Group Queue After Removal :: Account :: #{current_account.id} :: Key :: #{group_queue_key} :: Value :: #{group_calls.inspect}"
      set_key(group_queue_key, group_calls.to_json)
    end
  end

  def check_for_priority_calls
    agent_hunted_call or group_hunted_call
  end

  def agent_hunted_call
    Rails.logger.info "Inside Agent Hunt :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    agent_queue = get_key(agent_queue_key)
    if agent_queue
      agent_calls = JSON.parse(agent_queue)
      Rails.logger.info "Agent Hunt :: Account :: #{current_account.id} :: Key :: #{agent_queue_key} :: Value :: #{agent_calls.inspect}"
      if agent_calls.keys.include? @available_agent
        hunted_agent_calls = agent_calls[@available_agent]
        @priority_call = hunted_agent_calls ? hunted_agent_calls.first : nil
        Rails.logger.info "Agent Hunt :: Account :: #{current_account.id} :: Selected CallSid :: #{@priority_call.inspect}"
      end
    end
  end

  def group_hunted_call
    Rails.logger.info "Inside Group Hunt :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    agent = current_account.users.technicians.find_by_id(@available_agent)
    agent_groups = agent.agent_groups.collect{|ag| ag.group_id}
    group_queue = get_key(group_queue_key)
    if group_queue
      group_calls = JSON.parse(group_queue)
      Rails.logger.info "Group Hunt :: Account :: #{current_account.id} :: Key :: #{group_queue_key} Value :: #{group_calls.inspect}"
      hunted_group = group_calls.keys.select{|group| agent_groups.include? group.to_i }.first
      hunted_group_calls = group_calls[hunted_group]
      @priority_call = hunted_group_calls ? hunted_group_calls.first : nil
      Rails.logger.info "Group Hunt :: Account :: #{current_account.id} :: Selected CallSid :: #{@priority_call.inspect}"
    end
  end

  def default_queue_call
    Rails.logger.info "Inside Simple Hunt :: Account :: #{current_account.id} :: Agent :: #{@available_agent}"
    queued_calls = get_key(default_queue_key)
    if queued_calls
      calls = JSON.parse(queued_calls)
      Rails.logger.info "Simple Hunt :: Account :: #{current_account.id} :: Key :: #{default_queue_key} :: Value :: #{calls.inspect}"
      calls.first
    end
  end

  def add_caller_to_redis_queue
    return normal_queue if params[:hunt_type].blank?
    priority_queue
  end

  def normal_queue
    calls = get_key(default_queue_key)
    waiting_calls = (calls) ? JSON.parse(calls) : []
    Rails.logger.info "Simple Queue Before Adding :: Account :: #{current_account.id} :: Key :: #{default_queue_key} Value :: #{waiting_calls.inspect}"
    unless waiting_calls.include? params[:CallSid]
      waiting_calls << params[:CallSid]
      set_key(default_queue_key, waiting_calls.to_json)
      Rails.logger.info "Simple Queue After Adding :: Account :: #{current_account.id} :: Key :: #{default_queue_key} Value :: #{waiting_calls.inspect}"
    end
  end

  def priority_queue
    priority_queue_key = safe_send("#{params[:hunt_type]}_queue_key")
    calls = get_key(priority_queue_key)
    waiting_calls = (calls) ? JSON.parse(calls) : {}
    waiting_calls[params[:hunt_id]] ||= []
    Rails.logger.info "Priority Queue Before Adding :: Account :: #{current_account.id} :: Key :: #{priority_queue_key} :: Value :: #{waiting_calls.inspect}"
    unless waiting_calls[params[:hunt_id]].include? params[:CallSid]
      waiting_calls[params[:hunt_id]] << params[:CallSid] 
      set_key(priority_queue_key, waiting_calls.to_json)
      Rails.logger.info "Priority Queue After Adding :: Account :: #{current_account.id} :: Key :: #{priority_queue_key} :: Value :: #{waiting_calls.inspect}"
    end
  end

  private
    def queued_members
      queue_sid = current_account.freshfone_account.queue
      @queued_members ||= current_account.freshfone_subaccount.queues.get(queue_sid).members
    end

    def load_hunt_options_for_conf
      call_meta = current_call.meta
      if current_account.features?(:freshfone_conference) && current_call.priority_queued_call?
        params[:hunt_id]   = (call_meta.agent_hunt? ? current_call.user_id : current_call.group_id).to_s
        params[:hunt_type] = Freshfone::CallMeta::HUNT_TYPE_REVERSE_HASH[call_meta.hunt_type].to_s if params[:hunt_id].present?
      end
    end

    def default_queue_key
      FRESHFONE_QUEUED_CALLS % { :account_id => current_account.id }
    end

    def group_queue_key
      FRESHFONE_GROUP_QUEUE % { :account_id => current_account.id }
    end

    def agent_queue_key
      FRESHFONE_AGENT_QUEUE % { :account_id => current_account.id }
    end

    def resque_queue_wait_key
      FRESHFONE_QUEUE_WAIT % {:account_id => current_account.id, :call_sid => params[:CallSid]}
    end

    def play_default_music(xml_builder)
      xml_builder.Play Freshfone::Number::DEFAULT_QUEUE_MUSIC, :loop => 50
    end

    def add_to_call_queue_worker(async = false, user_id = current_user.id, parameters = params)
      return Freshfone::CallQueueWorker.perform_async(parameters.merge(:account_id => ::Account.current.id), user_id) if async
      Resque.enqueue_at(10.seconds.from_now, Freshfone::Jobs::CallQueuing,
          parameters.merge(account_id: ::Account.current.id, agent: user_id))
    end

    def read_queue_position_message(xml_builder)
      return if current_number.queue_position_message.blank?
      queue_values = { "position" => params['QueuePosition']}
      text = Liquid::Template.parse(current_number.queue_position_message).render("queue" => queue_values)
      xml_builder.Say "#{text}", { :voice => current_number.voice_type }
    end

    def load_freshfone_user
      current_user ||= current_account.technicians.visible.find(params[:agent] || params[:agent_id])
      @freshfone_user ||= current_user.freshfone_user if current_user.present?
    end

    def check_for_queued_calls
      load_freshfone_user
      return unless @freshfone_user.present? && @freshfone_user.online?
      add_to_call_queue_worker(true, @freshfone_user.user_id) if params[:CallStatus].present? && Freshfone::CallMeta::MISSED_RESPONSE_HASH.key?(params[:CallStatus].to_sym)
    end

end

module Freshfone::Queue
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  BRIDGE_STATUS = ["redirected", "bridged"]

	def enqueue_caller
    twiml = Twilio::TwiML::Response.new do |r|
      current_number.read_queue_message(r)
      r.Gather :action => "#{host}/freshfone/queue/quit_queue_on_voicemail", :numDigits => '1' do |g|
        g.Play "http://com.twilio.music.guitars.s3.amazonaws.com/Pitx_-_A_Thought.mp3"
      end
    end
    render :xml => twiml.text
  end

  def bridge_queued_call(agent = nil)
    @available_agent = (agent or default_client).to_s
    @priority_call = nil
    if queued_members.list.any?
      check_for_priority_calls
      @priority_call ? bridge_priority_call : bridge_normal_call
    end
  end

  def bridge_priority_call
    begin
      member = queued_members.get(@priority_call)
      member.update(:url => "#{host}/freshfone/queue/dequeue?client=#{@available_agent}")
    rescue Twilio::REST::RequestError => e
      Rails.logger.error "Error trying to dequeue Priority call: #{e.message}"
      agent_hunted_call ? remove_call_sid_from_agent_queue : 
        remove_call_sid_from_group_queue
      bridge_queued_call
    end
  end

  def bridge_normal_call
    if default_queue_call
      member = queued_members.get(default_queue_call)
      begin
        member.update(:url => "#{host}/freshfone/queue/dequeue")
      rescue Twilio::REST::RequestError => e
        Rails.logger.error "Error trying to dequeue call: #{e.message}"
        remove_call_sid_from_default_queue
        bridge_queued_call
      end
    end
  end

  def remove_call_sid_from_default_queue
    queued_calls = get_key(default_queue_key)
    if queued_calls
      calls = JSON.parse(queued_calls)
      calls.delete(calls.first)
      set_key(default_queue_key, calls.to_json)
    end
  end

  def remove_call_sid_from_agent_queue
    agent_queue = get_key(agent_queue_key)
    if agent_queue
      calls = JSON.parse(agent_queue)
      if calls.keys.include? @available_agent
        hunted_agent_calls = calls[@available_agent]
        hunted_agent_calls.delete(hunted_agent_calls.first)
        calls[@available_agent] = hunted_agent_calls
      end
      set_key(agent_queue_key, calls.to_json)
    end
  end

  def remove_call_sid_from_group_queue
    group_queue = get_key(group_queue_key)
    agent = current_account.users.technicians.find_by_id(@available_agent)
    agent_groups = agent.agent_groups.collect{|ag| ag.group_id}
    if group_queue
      group_calls = JSON.parse(group_queue)
      hunted_group = group_calls.keys.select{|group| agent_groups.include? group.to_i }.first
      hunted_group_calls = group_calls[hunted_group]
      hunted_group_calls.delete(hunted_group_calls.first)
      group_calls[hunted_group] = hunted_group_calls
    end
    set_key(group_queue_key, group_calls.to_json)
  end

  def check_for_priority_calls
    agent_hunted_call or group_hunted_call
  end

  def agent_hunted_call
    agent_queue = get_key(agent_queue_key)
    if agent_queue
      agent_calls = JSON.parse(agent_queue)
      if agent_calls.keys.include? @available_agent
        hunted_agent_calls = agent_calls[@available_agent]
        @priority_call = hunted_agent_calls ? hunted_agent_calls.first : nil
      end
    end
  end

  def group_hunted_call
    agent = current_account.users.technicians.find_by_id(@available_agent)
    agent_groups = agent.agent_groups.collect{|ag| ag.group_id}
    group_queue = get_key(group_queue_key)
    if group_queue
      group_calls = JSON.parse(group_queue)
      hunted_group = group_calls.keys.select{|group| agent_groups.include? group.to_i }.first
      hunted_group_calls = group_calls[hunted_group]
      @priority_call = hunted_group_calls ? hunted_group_calls.first : nil
    end
  end

  def default_queue_call
    queued_calls = get_key(default_queue_key)
    if queued_calls
      calls = JSON.parse(queued_calls)
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
    unless waiting_calls.include? params[:CallSid]
      waiting_calls << params[:CallSid] 
      set_key(default_queue_key, waiting_calls.to_json)
    end
  end

  def priority_queue
    priority_queue_key = send("#{params[:hunt_type]}_queue_key")
    calls = get_key(priority_queue_key)
    waiting_calls = (calls) ? JSON.parse(calls) : {}
    waiting_calls[params[:hunt_id]] ||= [] 
    unless waiting_calls[params[:hunt_id]].include? params[:CallSid]
      waiting_calls[params[:hunt_id]] << params[:CallSid] 
      set_key(priority_queue_key, waiting_calls.to_json)
    end
  end

  private
    def queued_members
      queue_sid = current_account.freshfone_account.queue
      @queued_members ||= current_account.freshfone_subaccount.queues.get(queue_sid).members
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


end
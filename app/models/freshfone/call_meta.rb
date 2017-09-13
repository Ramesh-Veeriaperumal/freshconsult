class Freshfone::CallMeta < ActiveRecord::Base
  include Freshfone::CallsRedisMethods
  self.table_name =  :freshfone_calls_meta
  self.primary_key = :id

  belongs_to_account
  serialize :meta_info, Hash
  belongs_to :freshfone_call, :class_name => "Freshfone::Call", :foreign_key => 'call_id'
  belongs_to :group
  
  serialize :pinged_agents

  USER_AGENT_TYPE =[ 
      [:browser, 1],
      [:android, 2 ],
      [:ios, 3],
      [:available_on_phone, 4],
      [:direct_dial, 5],
      [:external_transfer, 6],
      [:sip,7]
    ]
  
  PINGED_AGENT_RESPONSE = [
    [:accepted, 1],
    [:completed, 1],
    [:'no-answer', 2],
    [:busy, 3],
    [:canceled, 4],
    [:failed, 5],
  ]

  HUNT_TYPE = {
    :agent => 0,
    :group => 1,
    :number => 2,
    :simple_routing => 3
  }

  ISSUE_TYPE = [
    ['imperfect_audio', :imperfect_audio],
    ['dropped_call', :dropped_call],
    ['audio_latency', :audio_latency],
    ['one_way_audio', :one_way_audio],
    ['other_issues', :other]
  ]

  RATING_TYPE = [
    ['good', :good],
    ['bad', :bad]
  ]

  ISSUE_TYPE_HASH = Hash[*ISSUE_TYPE.map { |i| [i[0], i[1]] }.flatten]

  RATING_TYPE_HASH = Hash[*RATING_TYPE.map { |i| [i[0], i[1]] }.flatten]

  HUNT_TYPE_HASH = Hash[*HUNT_TYPE.map { |i| [i[0], i[1]] }.flatten]
  HUNT_TYPE_REVERSE_HASH = Hash[*HUNT_TYPE.map { |i| [i[1], i[0]] }.flatten]

  USER_AGENT_TYPE_HASH = Hash[*USER_AGENT_TYPE.map { |i| [i[0], i[1]] }.flatten]
  USER_AGENT_TYPE_REVERSE_HASH = Hash[*USER_AGENT_TYPE.map { |i| [i[1], i[0]] }.flatten]

  PINGED_AGENT_RESPONSE_HASH = Hash[*PINGED_AGENT_RESPONSE.map { |i| [i[0], i[1]] }.flatten]
  PINGED_AGENT_RESPONSE_REVERSE_HASH = Hash[*PINGED_AGENT_RESPONSE.map { |i| [i[1], i[0]] }.flatten]

  MISSED_RESPONSE_HASH = PINGED_AGENT_RESPONSE_HASH.slice(:'no-answer', :busy, :canceled, :failed)

  HUNT_TYPE.each do |k, v|
    define_method("#{k}_hunt?") do
      hunt_type == v
    end
  end

  HUNT_TYPE.each do |k, v|
    define_method("#{k}_hunt!") do
      self.hunt_type = v
      save
    end
  end

  USER_AGENT_TYPE_HASH.each_pair do |k,v|
    define_method("#{k.to_s}?") do
      device_type == v
    end
  end

  def update_agent_call_sids(user_id, call_sid)
    pinged_agents.each do |agent|
      agent.merge!({:call_sid => call_sid}) if agent[:id] == user_id.to_i
    end
    save!
  end

  def all_agents_missed?
    agents_response = get_response_meta(account_id, call_id)
    agents_response.length ==  pinged_agents.length &&
      (agents_response.values - missed_agent_response_hash).blank?
  end

  def update_mobile_agent_call(user_id, call_sid) # Spreadheet L 27
    update_agent_call_sids(user_id, call_sid)
  end

  def update_external_transfer_call(number, call_sid)
    self.device_type = Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer]
    save
  end

  def update_external_transfer_call_response(number, response)
    pinged_agents.each do |agent|
      agent.merge!({:response => PINGED_AGENT_RESPONSE_HASH[response.to_sym]}) if agent[:number] == number
    end
    save
  end

  def update_pinged_agent_ringing_at(agent_id)
    pinged_agents.each do |agent|
      agent.merge!({ :ringing_at => Time.zone.now }) if agent[:id] == agent_id.to_i
    end
    save!
  end

  def update_agent_ringing_time(agent_id)
    pinged_agents.each do |agent|
      agent.merge!({ :ringing_time => (Time.zone.now - agent[:ringing_at]).to_i.abs }) if agent[:id] == agent_id.to_i && agent[:ringing_at].present?
    end
    save!
  end

  def pinged_agent_ringing_time(agent_id, answered_at)
    pinged_agents.each do |agent|
      if agent[:id] == agent_id.to_i
        return (answered_at - agent[:ringing_at]).to_i.abs if agent[:ringing_at].present?
      end
    end
  end

  def missed_response_present?(user_id)
    agent_response = get_agent_response(account_id, call_id, user_id)
    missed_agent_response_hash.include?(agent_response)
  end

  def any_agent_accepted?
    pinged_agents.find do |agent| 
      agent[:response] == PINGED_AGENT_RESPONSE_HASH[:accepted]
    end.present?
  end

  def update_feedback(params)
    meta_info[:quality_feedback] = build_feedback_params(params)
    save! if meta_info[:quality_feedback].present?
  end

  def cancel_all_agents
    cancel_ringing_agents([:browser, :mobile])
  end

  def cancel_browser_agents
    cancel_ringing_agents([:browser])
  end

  def cancel_ringing_agents(device)
    agents_response = []
    redis_response = get_response_meta(account_id, call_id)
    missed_agents = pinged_agents.select { |agent|
      missed_agent?(agent, redis_response[agent[:id].to_s], device) }
    missed_agents.each do |agent|
      agents_response.push(agent[:id], :canceled)
    end
    set_all_agents_response(account_id, call_id,
      agents_response) if agents_response.present?
  end

  def agent_pinged_and_no_response?(user_id)
    pinged_agents.each do |agent|
      return true if agent[:id] == user_id && agent[:response].blank?
    end
    false
  end

  def simple_or_group_hunt?
    simple_routing_hunt? || group_hunt?
  end

  def android_or_ios?
    android? || ios?
  end
  
  def warm_transfer_meta?
    meta_info[:type] == 'warm_transfer'
  end

  def warm_transfer_revert?
    meta_info.is_a?(Hash) && meta_info[:type] == 'warm_transfer' &&
                      freshfone_call.user_id == freshfone_call.parent.user_id
  end

  def warm_transfer_success?
    meta_info[:type] == 'warm_transfer' && 
                      freshfone_call.user_id != freshfone_call.parent.user_id
  end

  def forward?
    direct_dial? || external_transfer? || available_on_phone?
  end

  def agent_pinged?(user_id)
    pinged_agents.each do |agent|
      return true if agent[:id] == user_id
    end
    false
  end

  private

    def on_device?(agent, device)
      device.include?(agent[:device_type])
    end

    def build_feedback_params(params)
      result = {}
      result[:rating] = RATING_TYPE_HASH[params[:rating]] if params[:rating].present?
      result[:issue] = ISSUE_TYPE_HASH[params[:issue]] if params[:issue].present?
      result[:comment] = CGI::escapeHTML(params[:comment]) if params[:comment].present?
      result
    end

    def missed_agent?(agent, agent_response, device)
      on_device?(agent, device) && agent[:id] != freshfone_call.user_id &&
        agent_response.blank?
    end

    def missed_agent_response_hash
      MISSED_RESPONSE_HASH.keys.map { |k| k.to_s}
    end
end
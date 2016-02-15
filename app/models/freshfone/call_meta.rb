class Freshfone::CallMeta < ActiveRecord::Base
  self.table_name =  :freshfone_calls_meta
  self.primary_key = :id

  belongs_to_account
  belongs_to :freshfone_call, :class_name => "Freshfone::Call"
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
  
  def update_pinged_agents_with_response(user_id, response)
    pinged_agents.each do |agent|
      agent.merge!({:response => PINGED_AGENT_RESPONSE_HASH[response.to_sym]}) if agent[:id] == user_id.to_i && agent[:response].blank?
    end
    save!
  end

  def update_agent_call_sids(user_id, call_sid)
    pinged_agents.each do |agent|
      agent.merge!({:call_sid => call_sid}) if agent[:id] == user_id.to_i
    end
    save!
  end

  def all_agents_missed?
    pinged_agents.find do |agent| 
      MISSED_RESPONSE_HASH.values.exclude? agent[:response]
    end.blank?
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
      agent.merge!({ :ringing_time => (Time.zone.now - agent[:ringing_at]).to_i.abs }) if agent[:id] == agent_id.to_i
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

  def agent_response_present?(user_id)
    pinged_agents.each do |agent|
      return agent[:response].present? if agent[:id] == user_id.to_i
    end
    false
  end

  def update_device_meta(device_type, meta_info)
    self.device_type = device_type
    self.meta_info = meta_info
    save
  end

  def any_agent_accepted?
    pinged_agents.find do |agent| 
      agent[:response] == PINGED_AGENT_RESPONSE_HASH[:accepted]
    end.present?
  end

end
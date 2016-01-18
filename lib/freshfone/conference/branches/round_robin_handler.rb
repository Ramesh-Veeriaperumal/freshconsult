module Freshfone::Conference::Branches::RoundRobinHandler
  include Freshfone::CallsRedisMethods
  include Freshfone::Call::Branches::Bridge
  
  def handle_round_robin_calls
    update_last_pinged_agent
    if round_robin_agents_pending?
      initiate_round_robin
    else
      if params[:round_robin_call].present?
        reset_presence_for_forward_calls
        end_customer_conference if batch_agents_online.blank?
        clear_batch_key(get_call_sid) 
      end
    end
  end

  def update_last_pinged_agent
    agent = params[:agent_id] || params[:agent]
    current_call.meta.update_agent_ringing_time agent
  end

  def initiate_round_robin
    notifier.initiate_round_robin(current_call, get_batch_agents_hash) if current_call.can_be_connected?
  end

  private
    def round_robin_agents_pending?
      missed_call? && batch_agents_ids.present? && batch_agents_online.present?
    end

    def reset_presence_for_forward_calls
      return unless params[:CallStatus] == 'completed'
      update_mobile_user_presence
    end

    def batch_agents_ids
      @batch_agents_ids ||= begin
        key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => get_call_sid }
        batch_agents_ids = get_key(key)
        remove_key(key)
        batch_agents_ids.blank? ? batch_agents_ids : JSON::parse(batch_agents_ids)
      end
    end

    def batch_agents_online
      freshfone_number = current_number || current_call.freshfone_number 
      sort_order = freshfone_number.round_robin? ?  "ASC" : "DESC"
      @available_agents = current_account.freshfone_users.agents_by_last_call_at(sort_order).find_all_by_id(batch_agents_ids)
    end

    def get_call_sid
      current_call.call_sid
    end

    def get_batch_agents_hash
      batch_agents_online.map {|freshfone_user|
         {:id => freshfone_user.user_id, 
          :ff_user_id => freshfone_user.id,
          :name => freshfone_user.name,
          :device_type => freshfone_user.available_on_phone? ? :mobile : :browser }
      }
    end

    def end_customer_conference
      initiate_voicemail if (params[:CallStatus]!= "completed")
    end

    def missed_call?
      Freshfone::CallInitiator::VOICEMAIL_TRIGGERS.include?(params[:CallStatus]) and 
          !current_call.outgoing?
    end

    def call_forwarded?
      params[:forward_call].present?
    end
end
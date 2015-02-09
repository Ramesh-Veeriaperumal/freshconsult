class Freshfone::Jobs::BusyResolve
  extend Resque::AroundPerform
  include Redis::RedisKeys

  @queue = "freshfone_default_queue"

  def self.perform(args)
    #Don't add jobs if already added for the same user
    return unless freshfone_account_active?
    @account = Account.current
    @agent_id = args[:agent_id]
    Rails.logger.debug "BusyResolve: Checking whether to update 
      busy state for account #{@account.id} and user #{@agent_id}"
    remove_busy_statuses if no_active_calls
  end

  private

    def self.freshfone_account_active?
      Account.current.freshfone_account && Account.current.freshfone_account.active?
    end

    def self.no_active_calls
      return true if in_progress_calls.empty?
      get_updated_call_status @calls_in_progress.first
      in_progress_calls.empty?
    end

    def self.in_progress_calls
      @calls_in_progress = @account.freshfone_calls.agent_progress_calls(@agent_id)
    end

    def self.get_updated_call_status call
      twilio_call_status = get_twilio_call_status call.call_sid
      call.update_attributes(:call_status => twilio_call_status) unless twilio_call_status.nil? ||
        twilio_call_status == Freshfone::Call::CALL_STATUS_STR_HASH['in-progress']
    end

    def self.get_twilio_call_status(sid)
      begin
        status = @account.freshfone_subaccount.calls.get(sid).status
        Freshfone::Call::CALL_STATUS_STR_HASH[status]
      rescue => e
        Rails.logger.debug "Twilio api request error in BusyResolve
        for account #{@account.id} and user #{@agent_id} => #{e}"
        return nil
      end
    end

    def self.remove_busy_statuses
      check_remove_devices
      update_user_presence
    end

    def self.update_user_presence
      user = @account.freshfone_users.find_by_user_id(@agent_id)
      user.reset_presence.save if user.busy?
    end

    def self.check_remove_devices
      [outgoing_key, live_calls_key].map { |key| remove_agent_from_redis_set(key) if is_device_set?(key) }
    end

    def self.outgoing_key
      FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
    end

    def self.live_calls_key
      NEW_CALL % { :account_id => @account.id }
    end

    def self.is_device_set? key
      begin
        return $redis_integrations.sismember key, @agent_id
      rescue => e
        Rails.logger.debug "SMEMBERS Redis method error in BusyResolve
        for account #{@account.id} and user #{@agent_id} => #{e}"
        return nil
      end
    end

    def self.remove_agent_from_redis_set key
      begin
        return $redis_integrations.srem key, @agent_id
      rescue => e
        Rails.logger.debug "SREM Redis method error in BusyResolve
        for account #{@account.id} and user #{@agent_id} => #{e}"
        return nil
      end
    end
end

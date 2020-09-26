class Freshfone::UserObserver < ActiveRecord::Observer
  observe Freshfone::User
  include Freshfone::Queue
  include Freshfone::NodeEvents
  include Freshfone::AcwUtil

  def after_save(freshfone_user)
    publish_presence(freshfone_user) if freshfone_user.presence_changed?
  end

  def after_commit(freshfone_user)
    check_for_queued_calls(freshfone_user) if freshfone_user.previous_changes[:presence].present?
    publish_capability_token(freshfone_user.user, freshfone_user.get_capability_token) unless
        freshfone_user.previous_changes[:capability_token_hash]
  end

  def after_destroy(freshfone_user)
    publish_presence(freshfone_user, true)
  end

  private

    def publish_presence(freshfone_user, deleted = false)
      publish_freshfone_presence(freshfone_user.user, deleted)
      if freshfone_user.busy?
        publish_live_call({}, freshfone_user.account, freshfone_user.user_id)
      elsif (freshfone_user.presence_was == Freshfone::User::PRESENCE[:busy])
        unpublish_live_call({}, freshfone_user.account)
      elsif ((freshfone_user.presence_was == Freshfone::User::PRESENCE[:acw]) && !deleted)
        validate_call_work_time(freshfone_user)
      end
    end

    def check_for_queued_calls(freshfone_user)
      return unless freshfone_user.online?
      was_busy = [Freshfone::User::PRESENCE[:busy],
        Freshfone::User::PRESENCE[:acw]].include?(
        freshfone_user.previous_changes[:presence].first)
      Rails.logger.info "Call Queue Worker Initiated :: Account :: #{freshfone_user.account_id} :: User :: #{freshfone_user.user_id} :: User Was Busy :: #{was_busy}"
      add_to_call_queue_worker(was_busy, freshfone_user.user_id, {})
    end

    def validate_call_work_time(freshfone_user)
      call = freshfone_user.user.freshfone_calls.last
      return if call_work_time_updated?(call)
      call.update_acw_duration if call.account.features? :freshfone_call_metrics
    end
end

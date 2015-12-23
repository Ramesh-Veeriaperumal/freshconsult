class Freshfone::UserObserver < ActiveRecord::Observer
  observe Freshfone::User
  include Freshfone::Queue
  include Freshfone::NodeEvents

  def after_save(freshfone_user)
    if freshfone_user.presence_changed?
      publish_presence(freshfone_user)
      check_for_queued_calls(freshfone_user)
    end
  end

  def after_commit(freshfone_user)
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
      end
    end

    def check_for_queued_calls(freshfone_user)
      return unless freshfone_user.online?
      add_to_call_queue_worker(
        freshfone_user.presence_was == Freshfone::User::PRESENCE[:busy],
        freshfone_user.user_id, {})
    end
end

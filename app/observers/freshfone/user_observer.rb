class Freshfone::UserObserver < ActiveRecord::Observer
  observe Freshfone::User

  include Freshfone::NodeEvents

  def after_save(freshfone_user)
    publish_presence(freshfone_user) if freshfone_user.presence_changed?
    publish_capability_token(freshfone_user, freshfone_user.get_capability_token)
  end

  def after_destroy(freshfone_user)
    publish_presence(freshfone_user, true)
  end

  private

    def publish_presence(freshfone_user, deleted = false)
      publish_freshfone_presence(freshfone_user.user, deleted)
      if busy_state?(freshfone_user)
        publish_live_call({},freshfone_user.account, freshfone_user.user_id) 
      elsif (freshfone_user.presence_was == Freshfone::User::PRESENCE[:busy] )
        unpublish_live_call({},freshfone_user.account)
      end
    end

    def busy_state?(freshfone_user)
      freshfone_user.busy? 
    end
end

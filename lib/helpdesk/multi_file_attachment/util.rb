module Helpdesk::MultiFileAttachment::Util
  include Redis::RedisKeys
  include Redis::OthersRedis

  def mark_for_cleanup(attachment_id, account_id = Account.current.id)
    add_member_to_redis_set(user_draft_redis_key, construct_set_value(attachment_id, account_id))
  end

  def unmark_for_cleanup(attachment_id, account_id = Account.current.id)
    remove_member_from_redis_set(user_draft_redis_key, construct_set_value(attachment_id, account_id))
  end

  private
    def user_draft_redis_key(date=Time.now.utc)
      MULTI_FILE_ATTACHMENT % {:date => date.strftime("%Y-%m-%d")}
    end

    def construct_set_value(attachment_id, account_id)
      "#{account_id}:#{attachment_id}"
    end
end

module YearInReviewMethods

  include Redis::RedisKeys
  include Redis::OthersRedis

  private

  def fetch_review
    return { shared: false } unless review_available?
    {
      shared: @shared || false,
      url: @url,
      user_closed: @user_closed,
      download: @download
    }
  end

  def review_available?
    admin_privileged? || url_shared?
  end

  def admin_privileged?
    return false unless (User.current.privilege?(:view_reports) && User.current.agent.all_ticket_permission)
    yir_redis_pipeline
  end

  def url_shared?
    yir_redis_pipeline
    @shared
  end

  def yir_redis_pipeline
    url_info = []
    url_info, @user_closed = $redis_others.pipelined do
      get_others_redis_hash(yir_account_key)
      ismember?(yir_closed_key, User.current.id)
    end
    @shared, @url, @download = url_info['shared'] == "1", url_info['url'], url_info['download']
  end

  def yir_account_key
    YEAR_IN_REVIEW_ACCOUNT % { account_id: Account.current.id }
  end

  def yir_closed_key
    YEAR_IN_REVIEW_CLOSED_USERS % { account_id: Account.current.id }
  end

  def share_video
    set_others_redis_hash_set(yir_account_key, 'shared', '1')
    Rails.logger.info "Year in Review :: Shared video for agents :: Admin::#{Account.current.id}::#{User.current.id}"
  end

  def clear_review_box
    add_member_to_redis_set(yir_closed_key, User.current.id)
    Rails.logger.info "Year in Review :: User closed video bar :: #{Account.current.id}::#{User.current.id}"
  end
end

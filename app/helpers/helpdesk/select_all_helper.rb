module Helpdesk::SelectAllHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def render_select_all_toolbar?
    @current_view != "deleted" && @current_view != "spam" && select_all_available?
  end

  def select_all_available?
    privilege?(:admin_tasks) && current_account.select_all_enabled?
  end

  def select_all_running_job
    get_others_redis_hash(SELECT_ALL % {:account_id => current_account.id})
  end
end

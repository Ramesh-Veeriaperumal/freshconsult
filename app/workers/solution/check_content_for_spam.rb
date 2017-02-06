class Solution::CheckContentForSpam < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis


  sidekiq_options :queue => :kbase_content_spam_checker, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    check_description_for_spam args[:article_id]
  end

  private

  def check_description_for_spam article_id
    article = @account.solution_articles.find(article_id)
    article_spam_regex = Regexp.new($redis_others.perform_redis_op("get", ARTICLE_SPAM_REGEX), "i")
    desc_un_html_lines = article.desc_un_html.split("\n")
    spam_content = false
    desc_un_html_lines.each do |desc_line|
      spam_content = true and break if (desc_line =~ article_spam_regex).present?
    end
    increase_ehawk_spam_score_for_account(4, article_id) if spam_content
  end
   
  def increase_ehawk_spam_score_for_account(spam_score, article_id)
    signup_params = (get_signup_params || {}).merge({"api_response" => {}})
    signup_params["api_response"]["status"] = spam_score
    set_others_redis_key(signup_params_key,signup_params.to_json)
    @account.conversion_metric.update_attribute(:spam_score, spam_score) if @account.conversion_metric
    increment_portal_cache_version
    Rails.logger.info ":::::: Kbase spam content encountered - increased spam reputation for article ##{article_id} in account ##{@account.id}  :::::::"
  end

  def signup_params_key
    ACCOUNT_SIGN_UP_PARAMS % {:account_id => Account.current.id}
  end

  def get_signup_params
    signup_params_json = get_others_redis_key(signup_params_key)
    return nil if signup_params_json.blank? ||  signup_params_json == "null"
    JSON.parse(get_others_redis_key(signup_params_key))
  end

  def increment_portal_cache_version
    return if get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false"
    key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
    increment_portal_redis_version key
  end
end

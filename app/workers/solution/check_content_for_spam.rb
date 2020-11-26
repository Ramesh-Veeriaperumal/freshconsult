class Solution::CheckContentForSpam < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis
  include Email::Antivirus::EHawk

  sidekiq_options :queue => :kbase_content_spam_checker, :retry => 1, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    Rails.logger.info "Running CheckContentForSpam for Account : #{Account.current.id}, article_id: #{args[:article_id].to_s} "
    check_description_for_spam args[:article_id]
  end

  private

  def check_description_for_spam article_id
    article = @account.solution_articles.find_by_id(article_id)
    return if article.nil?

    spam_content = false
    article_spam_regex = Regexp.new($redis_others.perform_redis_op("get", ARTICLE_SPAM_REGEX), "i")
    article_phone_number_spam_regex = Regexp.new($redis_others.perform_redis_op("get", PHONE_NUMBER_SPAM_REGEX), "i")
    article_content_spam_char_regex = Regexp.new($redis_others.perform_redis_op("get", CONTENT_SPAM_CHAR_REGEX))
    stripped_article_content = article.desc_un_html.gsub(Regexp.new(Solution::Constants::CONTENT_ALPHA_NUMERIC_REGEX), "")
    response = FdSpamDetectionService::Service.new(@account.id, article.desc_un_html).check_spam_content(@account.created_at.iso8601)
    spam_content = response.spam?
    unless spam_content
      desc_un_html_lines = article.desc_un_html.split("\n")
      desc_un_html_lines.each do |desc_line|
        spam_content = true and break if ((desc_line =~ article_spam_regex).present? || (desc_line =~ article_content_spam_char_regex).present?)
      end
      spam_content = true if (stripped_article_content=~ article_phone_number_spam_regex).present?
    end
    Rails.logger.info "Article is spam? #{spam_content}"
    if spam_content
      subject = "Detected suspicious solution spam : Account id : #{Account.current.id}, Account state : #{Account.current.subscription.state}, Article id : #{article_id}, Domain : #{Account.current.full_domain}"
      additional_info = "Suspicious article in Account ##{Account.current.id} with ehawk_reputation_score: #{Account.current.ehawk_reputation_score} , Article id : #{article_id}"
      increase_ehawk_spam_score_for_account(4, @account, subject, additional_info)
      Rails.logger.info ":::::: Kbase spam content encountered - increased spam reputation for article ##{article_id} in account ##{@account.id}  :::::::"
    end
  end
end

class Solution::ArticleVersionsResetRating < BaseWorker
  sidekiq_options queue: :kbase_article_versions_reset_rating, retry: 4, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    @id = args[:id]

    return unless article
    #live version reset would have already happened, to account for any ratings before this job is picked up. This worked is only for resetting non live versions.
    versions = article.solution_article_versions.where('status = ? AND live = 0 AND (thumbs_up > 0 || thumbs_down > 0)', Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
    Rails.logger.info("AVRR :: Reset Rating START :: [Account Id :: #{Account.current.id} :: Article Id : #{@id} :: Version Count : #{versions.count}]")
    versions.each do |version|
      article.version_class.where({ :id => version.id}).update_all({:thumbs_up => 0, :thumbs_down => 0})
    end
    Rails.logger.info("AVRR :: Reset Rating END :: [Account Id :: #{Account.current.id} :: Article Id : #{@id}]")
  rescue => e
    Rails.logger.info "AVRR::Exception while running article version reset rating [Account Id :: #{Account.current.id} :: Article Id : #{@id}] #{e.message} - #{e.backtrace}"
    NewRelic::Agent.notice_error(e, account: Account.current.id, description: "Exception while running article version reset rating [Account: #{Account.current.id}, Article: #{@id}] #{e.message}")
  end

  private

    def article
      @article ||= Account.current.solution_articles.where(id: @id).first
    end
end
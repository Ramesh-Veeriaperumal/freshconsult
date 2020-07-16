module Search
  module Analytics
    class ArticleReindexWorker < ::BaseWorker
      SYNC_AGO = 900
      include BulkOperationsHelper
      sidekiq_options queue: :search_analytics_article_reindex, retry: 1, failures: :exhausted

      def perform(args)
        account = Account.current
        return unless account.active?

        args = HashWithIndifferentAccess.new(args)
        execute_on_db('run_on_slave') do
          relation = account.solution_articles
          individual_batch_size_limit = individual_batch_size
          relation.find_in_batches_with_rate_limit(batch_size: individual_batch_size_limit, rate_limit: rate_limit_options(args)) do |articles|
            push_articles_to_search(articles) if articles.present?
            log_time_in_additional_settings(account) if articles.size < individual_batch_size_limit
          end
        end
      rescue StandardError => e
        Rails.logger.error "Failure in Search::Analytics::ArticleReindexWorker :: #{e.message} :: #{args.inspect}"
        NewRelic::Agent.notice_error(e, description: "Failure in Search::Analytics::ArticleReindexWorker #{account.id}")
      ensure
        Account.reset_current_account
      end

      def push_articles_to_search(articles)
        articles.each do |article|
          begin
            search_payload = {
              'document_id' => article.id,
              'klass_name' => 'Solution::Article',
              'action' => 'update',
              'account_id' => Account.current.id,
              'type' => 'article',
              'version' => ([article.updated_at, SYNC_AGO.seconds.ago].max.to_f * 1_000_000).ceil
            }
            Search::V2::Operations::DocumentAdd.new(search_payload).perform
          rescue StandardError => e
            Rails.logger.error "Failure in Search::Analytics::ArticleReindexWorker :: #{e.message}"
            NewRelic::Agent.notice_error(e, description: "Failure in Search::Analytics::ArticleReindexWorker Article ID: #{article.id} :: Account ID: #{Account.current.id}")
          end
        end
      end

      def log_time_in_additional_settings(account)
        execute_on_db('run_on_master') do
          account.account_additional_settings.additional_settings[:last_article_reindexed_time] = Time.now.utc
          account.account_additional_settings.save
        end
      end
    end
  end
end

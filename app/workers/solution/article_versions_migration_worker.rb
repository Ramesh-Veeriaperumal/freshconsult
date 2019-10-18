class Solution::ArticleVersionsMigrationWorker < BaseWorker
  sidekiq_options queue: :kbase_article_versions_migration_worker, retry: 4, failures: :exhausted

  include Solution::ArticleVersioning

  def perform(args)
    args.symbolize_keys!
    @action = args[:action]
    Rails.logger.info "Running article versioning feature migration for [#{Account.current.id},#{@action}]"
    safe_send("#{@action}_versions")
  rescue => e # rubocop:disable RescueStandardError
    Rails.logger.info "Exception while article versioning feature migration for [#{Account.current.id},#{@action}] #{e.message} - #{e.backtrace}"
    NewRelic::Agent.notice_error(e, account: Account.current.id, description: "Exception while article versioning feature migration for [#{Account.current.id},#{@action}] #{e.message} - #{e.backtrace}")
  end

  def drop_versions
    account = Account.current
    Sharding.run_on_slave do
      account.solution_article_versions.find_each do |article_version|
        begin
          Sharding.run_on_master { article_version.destroy }
        rescue => e # rubocop:disable RescueStandardError
          Rails.logger.info "Exception while dropping article versioning feature migration for [#{account.id},#{article_version.id},#{@action}] #{e.message} - #{e.backtrace}"
          NewRelic::Agent.notice_error(e, account: account.id, description: "Exception while dropping article versioning feature migration for [#{account.id},#{article_version.id},#{@action}]")
        end
      end
    end
  end

  def add_versions
    account = Account.current
    Sharding.run_on_slave do
      account.solution_articles.find_each do |article|
        begin
          if article.solution_article_versions.empty?
            draft = article.draft
            Sharding.run_on_master do
              # if article is not published yet, we don't need to create a version. For published article we need to create two versions if it has draft.
              if article.status != Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
                version_record = version_create_or_update(article, true)
                version_record.created_at = article.created_at
                version_record.save
              end
              if draft
                version_record = version_create_or_update(draft, true)
                version_record.created_at = draft.created_at
                version_record.save
              end 
            end
          end
        rescue => e # rubocop:disable RescueStandardError
          Rails.logger.info "Exception while adding article versioning feature migration for [#{account.id},#{article.id},#{@action}] #{e.message} - #{e.backtrace}"
          NewRelic::Agent.notice_error(e, account: account.id, description: "Exception while adding article versioning feature migration for [#{account.id},#{article.id},#{@action}]")
        end
      end
    end
  end
end

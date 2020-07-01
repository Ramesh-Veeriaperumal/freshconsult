class UpdateArticlePlatformMappingWorker < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Utils::Freno
  include Sidekiq::Worker
  include BulkOperationsHelper
  include SolutionHelper
  sidekiq_options queue: :update_article_platform_mapping_worker, retry: 5, failures: :exhausted
  APPLICATION_NAME = 'UpdateArticlePlatformMappingWorker'.freeze

  def perform(args = {})
    args.symbolize_keys!
    @shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
    @lag_seconds = get_replication_lag_for_shard(APPLICATION_NAME, @shard_name)
    @join_condition = "inner join solution_platform_mappings on solution_platform_mappings.mappable_id = solution_article_meta.id and solution_platform_mappings.account_id = #{Account.current.id} and solution_platform_mappings.mappable_type = \"Solution::ArticleMeta\""
    if @lag_seconds > 0
      safe_send('freno_lags', args)
      rerun_after(@lag_seconds, args)
      return
    elsif args[:disabled_folder_platforms].present?
      safe_send('edit_article_platform_mapping', args)
    else
      safe_send('delete_article_platform_mapping', args)
    end
  rescue StandardError => e
    Rails.logger.error "Failure in UpdateArticlePlatformMappingWorker :: #{e.message} :: #{args.inspect}"
    NewRelic::Agent.notice_error(e, description: "Failure in UpdateArticlePlatformMappingWorker #{Account.current.id}")
  end

  private

    def rerun_after(lag, args)
      UpdateArticlePlatformMappingWorker.perform_in(lag, args)
    end

    def freno_lags(args)
      Rails.logger.debug("Warning: Freno: UpdateArticlePlatformMappingWorker: replication lag: #{@lag_seconds} secs :: #{args[:object_type]}_id:: #{args[:parent_level_id]} shard :: #{@shard_name}")
    end

    def edit_article_platform_mapping(args)
      parent_conditions = ["solution_folder_meta_id =  #{args[:parent_level_id]}"]
      if args[:disabled_folder_platforms].present?
        Account.current.solution_article_meta.joins(@join_condition).find_in_batches_with_rate_limit(conditions: parent_conditions, rate_limit: rate_limit_options(args)) do |articles|
          articles.each do |article|
            any_platforms_enabled?(article, args[:disabled_folder_platforms]) ? article.solution_platform_mapping.update_attributes(args[:disabled_folder_platforms]) : article.solution_platform_mapping.destroy
          end
        end
      end
    end

    def delete_article_platform_mapping(args)
      parent_conditions = ["solution_folder_meta_id =  #{args[:parent_level_id]}"]
      Account.current.solution_article_meta.joins(@join_condition).find_in_batches_with_rate_limit(conditions: parent_conditions, rate_limit: rate_limit_options(args)) do |articles|
        articles.each do |article|
          article.solution_platform_mapping.destroy
        end
      end
    end
end

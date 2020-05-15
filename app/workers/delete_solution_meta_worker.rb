class DeleteSolutionMetaWorker < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Utils::Freno
  include Sidekiq::Worker
  include BulkOperationsHelper
  sidekiq_options queue: :delete_solution_meta_worker, retry: 5, failures: :exhausted
  APPLICATION_NAME = 'DeleteSolutionMetaWorker'.freeze

  def perform(args = {})
    args.symbolize_keys!
    @shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
    @lag_seconds = get_replication_lag_for_shard(APPLICATION_NAME, @shard_name)
    if @lag_seconds > 0
      safe_send('freno_lags', args)
      rerun_after(@lag_seconds, args)
      return
    else
      safe_send("delete_#{args[:object_type]}", args)
    end
  end

  private

    def rerun_after(lag, args)
      DeleteSolutionMetaWorker.perform_in(lag, args)
    end

    def freno_lags(args)
      Rails.logger.debug("Warning: Freno: DeleteSolutionMetaWorker: replication lag: #{@lag_seconds} secs :: #{args[:object_type]}_id:: #{args[:parent_level_id]} shard :: #{@shard_name}")
    end

    def delete_folder_meta(args)
      parent_conditions = ["solution_folder_meta_id =  #{args[:parent_level_id]}"]
      Account.current.solution_article_meta.find_in_batches_with_rate_limit(conditions: parent_conditions, rate_limit: rate_limit_options(args)) do |articles|
        articles.each(&:destroy)
      end
    end

    def delete_category_meta(args)
      # Cannot use Account.current.solution_folder_meta as it will be a join query and the category would have already been deleted
      parent_conditions = ["solution_category_meta_id =  #{args[:parent_level_id]} and account_id = #{Account.current.id}"]
      Solution::FolderMeta.where(parent_conditions).find_in_batches_with_rate_limit(rate_limit: rate_limit_options(args)) do |folders|
        folders.each(&:destroy)
      end
    end
end

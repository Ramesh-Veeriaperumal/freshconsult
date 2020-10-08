class SearchV2::IndexOperations
  
  include Sidekiq::Worker
  include BulkOperationsHelper

  sidekiq_options :queue => :es_v2_queue, :retry => 2, :failures => :exhausted
  
  class UpdateArticleFolder < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      folder = Account.current.solution_folder_meta.find(args[:folder_id])
      folder.solution_articles.find_in_batches do |articles|
        articles.map(&:sqs_manual_publish_without_feature_check)
      end if folder
    end
  end
  
  class UpdateTopicForum < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      forum = Account.current.forums.find(args[:forum_id])
      forum.topics.find_in_batches do |topics|
        topics.map(&:sqs_manual_publish_without_feature_check)
      end if forum
    end
  end
  
  class UpdateTaggables < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      tag = Account.current.tags.find(args[:tag_id])
      tag.tag_uses.preload(:taggable).find_in_batches_with_rate_limit(rate_limit: rate_limit_options(args)) do |taguses|
        taguses.map(&:taggable).map(&:sqs_manual_publish_without_feature_check)
      end if tag
    end
  end
  
  class RemoveForumTopics < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      SearchService::Client.new(Account.current.id).delete_by_query('topic', { forum_id: args[:forum_id] })
    end
  end

end
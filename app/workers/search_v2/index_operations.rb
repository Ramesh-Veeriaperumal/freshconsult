class SearchV2::IndexOperations
  
  include Sidekiq::Worker

  sidekiq_options :queue => :es_v2_queue, :retry => 2, :backtrace => true, :failures => :exhausted
  
  class UpdateArticleFolder < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      folder = Account.current.solution_folder_meta.find(args[:folder_id])
      folder.articles.find_in_batches do |articles|
        articles.map(&:sqs_manual_publish_without_feature_check)
      end if folder and Account.current.try(:features?, :es_v2_writes)
    end
  end
  
  class UpdateTopicForum < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      forum = Account.current.forums.find(args[:forum_id])
      forum.topics.find_in_batches do |topics|
        topics.map(&:sqs_manual_publish_without_feature_check)
      end if forum and Account.current.try(:features?, :es_v2_writes)
    end
  end
  
  class UpdateTaggables < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      tag = Account.current.tags.find(args[:tag_id])
      tag.tag_uses.preload(:taggable).find_in_batches do |taguses|
        taguses.map(&:taggable).map(&:sqs_manual_publish_without_feature_check)
      end if tag and Account.current.try(:features?, :es_v2_writes)
    end
  end
  
  class RemoveForumTopics < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      Search::V2::IndexRequestHandler.new(
                                          'topic', 
                                          Account.current.id, 
                                          nil
                                        ).remove_by_query({ 
                                                            account_id: Account.current.id, 
                                                            forum_id: args[:forum_id] 
                                                          })
    end
  end

end
class SearchV2::IndexOperations
  
  include Sidekiq::Worker

  sidekiq_options :queue => :es_v2_queue, :retry => 2, :backtrace => true, :failures => :exhausted
  
  class UpdateArticleFolder < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      folder = Account.current.folders.find(args[:folder_id])
      folder_articles = folder.articles
      folder_articles.each do |article|
        article.sqs_manual_publish
      end unless folder_articles.blank?
    end
  end
  
  class UpdateTopicForum < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      forum = Account.current.forums.find(args[:forum_id])
      forum_topics = forum.topics
      forum_topics.each do |topic|
        topic.sqs_manual_publish
      end unless forum_topics.blank?
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
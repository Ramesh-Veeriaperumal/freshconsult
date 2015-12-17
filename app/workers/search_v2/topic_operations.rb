class SearchV2::TopicOperations < SearchV2::IndexOperations
  
  class UpdateForum < SearchSidekiq::IndexUpdate
    def perform(args)
      args.symbolize_keys!
      forum = Account.current.forums.find(args[:forum_id])
      forum_topics = forum.topics
      forum_topics.each do |topic|
        topic.send(:update_searchv2)
      end unless forum_topics.blank?
    end
  end
  
  class RemoveForumTopics < SearchSidekiq::IndexUpdate
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
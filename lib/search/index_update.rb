class Search::IndexUpdate

  extend Resque::AroundPerform
  include Tire::Model::Search

  class UserTickets < Search::IndexUpdate
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      user = Account.current.users.find(args[:user_id])
      user_tickets = user.tickets
      es_update(user_tickets) unless user_tickets.blank?
    end
  end

  class FolderArticles < Search::IndexUpdate
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      folder = Account.current.folders.find(args[:folder_id])
      folder_articles = folder.articles
      es_update(folder_articles) unless folder_articles.blank?
    end
  end

  class ForumTopics < Search::IndexUpdate
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      forum = Account.current.forums.find(args[:forum_id])
      forum_topics = forum.topics
      es_update(forum_topics) unless forum_topics.blank?
    end
  end

  def self.es_update(items)
    items.each do |item|
      item.update_es_index
    end
  end

end
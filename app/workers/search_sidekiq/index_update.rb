class SearchSidekiq::IndexUpdate < SearchSidekiq::BaseWorker

  class UserTickets < SearchSidekiq::IndexUpdate
    def perform(args)
      return unless Account.current.esv1_enabled?

      args.symbolize_keys!
      user = Account.current.all_users.find(args[:user_id])
      user.tickets.find_in_batches(:batch_size => 500) do |user_tickets|
        es_update(user_tickets)
      end
    end
  end

  class FolderArticles < SearchSidekiq::IndexUpdate
    def perform(args)
      return unless Account.current.esv1_enabled?

      args.symbolize_keys!
      folder = Account.current.solution_folder_meta.find(args[:folder_id])
      folder_articles = folder.solution_articles
      es_update(folder_articles) unless folder_articles.blank?
    end
  end

  class ForumTopics < SearchSidekiq::IndexUpdate
    def perform(args)
      return unless Account.current.esv1_enabled?

      args.symbolize_keys!
      forum = Account.current.forums.find(args[:forum_id])
      forum_topics = forum.topics
      es_update(forum_topics) unless forum_topics.blank?
    end
  end

  def es_update(items)
    items.each do |item|
      item.update_es_index
    end
  end
end

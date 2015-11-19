class SearchV2::ArticleOperations < SearchV2::IndexOperations
  
  class UpdateFolder < SearchSidekiq::IndexUpdate
    def perform(args)
      args.symbolize_keys!
      folder = Account.current.folders.find(args[:folder_id])
      folder_articles = folder.articles
      folder_articles.each do |ticket|
        ticket.send(:update_searchv2)
      end unless folder_articles.blank?
    end
  end

end
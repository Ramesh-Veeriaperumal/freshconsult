class Articles::Export::ArticlesExport < BaseWorker
  include Sidekiq::Worker
  sidekiq_options queue: :articles_export_queue, retry: 0, failures: :exhausted

  def perform(export_params)
    ::Export::Article.new(export_params).perform
  end
end

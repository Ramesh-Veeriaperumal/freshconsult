class Community::SolutionBinarizeSync < BaseWorker

  sidekiq_options :queue => :solution_binarize_sync, :retry => 0, :backtrace => true, :failures => :exhausted

  MODELS = {
    :solution_category_meta => [:solution_categories],
    :solution_folder_meta => [:solution_folders],
    :solution_article_meta => [:solution_articles, :draft]
  }

  def perform
    MODELS.each do |meta, association|
      sync_model(meta, association)
    end
  end

  private

    def sync_model(meta, association)
      Account.current.send(meta).find_in_batches(:batch_size => 100, :include => [association[0] => [association[1]].compact]) do |batch|
        batch.each do |sm|
          sm.children.each do |solution_obj|
            sm.class::BINARIZE_COLUMNS.each do |col|
              sm.compute_assign_binarize(col, solution_obj)
            end
          end
          sm.save
        end
      end
    end

end

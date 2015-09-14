class Solution::DraftMappingsObserver < ActiveRecord::Observer
    
  observe Solution::ArticleMeta, Solution::FolderMeta

  def after_update(object)
    send("fetch_#{object.class.name.tableize.split('/').last}", object)
  end

  private

    def fetch_article_meta(article_meta)
      return unless article_meta.changes[:solution_folder_meta_id]
      update_draft_category(article_meta, article_meta.solution_folder_meta.solution_category_meta_id)
    end

    def fetch_folder_meta(folder_meta)
      return unless folder_meta.changes[:solution_category_meta_id]  
      update_draft_category(folder_meta, folder_meta.solution_category_meta_id)
    end

    def update_draft_category(object, new_value)
      draft_ids = object.solution_articles(:include => :draft).map {|a| (a.draft || {})[:id] }.select(&:present?)
      Account.current.solution_drafts.where(:id => draft_ids).find_in_batches do |batch|
        Account.current.solution_drafts.where(:id => draft_ids).update_all(:category_meta_id => new_value)
      end
    end

end
module Mobihelp::MultilingualSolutionsUtils
  
  MULTILINGUAL_METHODS = [:solutions_with_category, :solutions_without_category]
  
  def self.included(base)
    base.send(:before_filter, :define_multilingual_methods)
  end
  
  def define_multilingual_methods
    @mobihelp_app.instance_eval do
      
      def solutions(category_id)
        MemcacheKeys.fetch(mobihelp_solutions_key_with_category_id(category_id)) {
          category_meta = Solution::CategoryMeta.includes(
            {:public_folder_meta => [ 
              {:published_article_meta => [:current_article_body, :tags]}]}).find_by_id category_id

          category_meta.to_json(:include => {:public_folders => 
            {:include => {:published_articles => {:include => {:tags => {:only => :name }}}},
            :except => [:account_id, :import_id]}})
        }
      end
      
    end
  end  
end
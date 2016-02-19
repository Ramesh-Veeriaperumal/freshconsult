class Support::Multilingual::SolutionsController < Support::SolutionsController

  private
    def load_category
      @category = current_portal.solution_category_meta.reorder('').find_by_id(params[:id])
      (raise ActiveRecord::RecordNotFound and return) if @category.nil?
    end

    def load_customer_categories
      @categories=[]
      solution_category_meta = @current_portal.solution_category_meta
      if solution_category_meta and solution_category_meta.respond_to?(:customer_categories)
        @categories = solution_category_meta.customer_categories.all(:include=>:public_folder_meta)
      else
        @categories = solution_category_meta; # in case of portal only selected solution is available.
      end
    end
end

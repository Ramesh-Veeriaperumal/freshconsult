class Mobihelp::Multilingual::SolutionsController < Mobihelp::SolutionsController
  
  include Mobihelp::MultilingualSolutionsUtils
    
  private
  
    def load_mobihelp_solution_category
      @category_ids = @mobihelp_app.app_solutions.pluck(:solution_category_meta_id)
    end
end

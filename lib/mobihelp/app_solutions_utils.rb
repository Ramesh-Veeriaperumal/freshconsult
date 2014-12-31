module Mobihelp::AppSolutionsUtils
  include Cache::Memcache::Mobihelp::Solution

  def update_mh_app_time(category_id)
    app_ids = Mobihelp::AppSolution.find_all_by_category_id(category_id, :select => :app_id).map(&:app_id)
    app_solutions = Mobihelp::AppSolution.find(:all, :conditions => ["app_id in (?)", app_ids])
    update_mobihelp_solutions_time(app_solutions)
    clear_solutions_cache(category_id)
  end

  def update_mh_solutions_category_time(category_id)
    app_solutions = Mobihelp::AppSolution.find_all_by_category_id(category_id)
    update_mobihelp_solutions_time(app_solutions)
    clear_solutions_cache(category_id)
  end

  private
    def update_mobihelp_solutions_time(mobihelp_app_solutions)
      mobihelp_app_solutions.each do |mobihelp_app_solution| 
        mobihelp_app_solution.updated_at = Time.now
        mobihelp_app_solution.save
      end
    end
end
module Mobihelp::AppSolutionsUtils
  include Cache::Memcache::Mobihelp::Solution

  def update_mh_app_time
    app_solutions = Mobihelp::AppSolution.find(:all, :conditions => ["app_id in (?)", mobihelp_app_ids])
    update_mobihelp_solutions_time(app_solutions)
    clear_solutions_cache
  end

  def update_mh_solutions_category_time
    update_mobihelp_solutions_time
    clear_solutions_cache
  end

  private
    def update_mobihelp_solutions_time(app_solutions=mobihelp_app_solutions)
      app_solutions.each do |mobihelp_app_solution| 
        mobihelp_app_solution.updated_at = Time.now
        mobihelp_app_solution.save
      end
    end
end
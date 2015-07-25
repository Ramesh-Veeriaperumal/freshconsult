module Mobihelp::AppSolutionsUtils
  include Cache::Memcache::Mobihelp::Solution

  def update_mh_app_time
    update_mobihelp_solutions_time
    clear_solutions_cache
  end

  def update_mh_solutions_category_time
    update_mobihelp_solutions_time
    clear_solutions_cache
  end

  private
    def update_mobihelp_solutions_time
      mobihelp_app_solutions.each do |mobihelp_app_solution| 
        mobihelp_app_solution.updated_at = Time.now
        mobihelp_app_solution.save
      end
    end
end
class Mobihelp::SolutionsController < MobihelpController

  include ReadsToSlave
  include Cache::Memcache::Mobihelp::Solution

  before_filter :load_mobihelp_solution_category, :only => :articles
  before_filter :check_solution_updated, :only => :articles
  FOLDER_TABLE_NAME = Solution::Folder.table_name
  ARTICLE_TABLE_NAME = Solution::Article.table_name
  
  def articles
    solution_data = "[]"
    if @category
      solution_data = @mobihelp_app.fetch_solutions(@category)
    end
    render_json(solution_data)
  end

  private

  def load_mobihelp_solution_category
    category_id = @mobihelp_app.config[:solutions].to_i
    if category_id > 0
      @category = current_portal.solution_categories.find_by_id(category_id)
    end
  end

  def render_json(data)
    respond_to do |format|
      format.json {
        render :json => data;
      }
    end
  end

  def check_solution_updated
    updated_since = params[:updated_since]
    unless updated_since.nil?
      begin
        updated_since = DateTime.rfc3339(updated_since)
      rescue Exception => e
        return ""
      end

      category_id = @mobihelp_app.config[:solutions].to_i;
      recently_updated_time = @mobihelp_app.fetch_recently_updated_time(category_id)
      render_json({:no_update => true}) if updated_since > recently_updated_time
    end
  end
end

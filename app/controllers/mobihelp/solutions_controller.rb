class Mobihelp::SolutionsController < MobihelpController

  include ReadsToSlave
  include Cache::Memcache::Mobihelp::Solution

  before_filter :check_solution_updated, :only => :articles
  before_filter :load_mobihelp_solution_category, :only => :articles

  # version 1 - Supports single solution category.
  # version 2 - Supports multiple solution categories with the order of position. Mobihelp SDK version 1.3
  #             or later support multiple solution categories.

  def articles
    solution_data = "[]"
    unless @categories.blank?
      if request_version_2?
        solution_data = @mobihelp_app.solutions_with_category(@categories)
      else
        solution_data = @mobihelp_app.solutions_without_category(@categories)
      end
    end
    render_json(solution_data)
  end

  private

  def load_mobihelp_solution_category
    category_ids = @mobihelp_app.app_solutions.all(:order => "position").map(&:category_id)
    @categories = current_account.solution_categories.where(id: category_ids).reorder("field(id, #{category_ids.join(',')})") if category_ids.any?
  end

  def render_json(data)
    respond_to do |format|
      format.json {
        render :json => data
      }
    end
  end

  def request_version_2?
    request.headers["X-API-Version"] == Mobihelp::App::API_VERSIONS_BY_NAME[:v_2]
  end

  def check_solution_updated
    updated_since = params[:updated_since]
    unless updated_since.nil?
      begin
        updated_since = DateTime.rfc3339(updated_since)
      rescue Exception => e
        return ""
      end

      last_updated_time =  @mobihelp_app.last_updated_time
      if last_updated_time.nil?
        render_json("[]")
      else
        render_json({:no_update => true})  if updated_since > last_updated_time
      end
    end
  end
end

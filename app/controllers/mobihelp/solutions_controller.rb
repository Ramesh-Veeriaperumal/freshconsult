class Mobihelp::SolutionsController < MobihelpController

  include ReadsToSlave

  before_filter :load_mobihelp_solution_category
  before_filter :check_solution_updated, :only => :articles
  FOLDER_TABLE_NAME = Solution::Folder.table_name
  ARTICLE_TABLE_NAME = Solution::Article.table_name
  
  def articles
    solution_data = "[]"
    if @category
      folder_json_strings = []
      @category.public_folders.each do |folder|
        folder_json_strings << folder.to_json(:include=>:published_articles) unless folder.published_articles.blank?
      end
      solution_data = "[#{folder_json_strings.join(",")}]";
    end
    render_json(solution_data)
  end

  private

  def load_mobihelp_solution_category
    category_id = @mobihelp_app.config[:solutions].to_i;
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
    unless updated_since.nil? or @category.nil? 
      begin
        updated_since = DateTime.rfc3339(updated_since)
      rescue Exception => e
        return ""
      end

      if @mobihelp_app.updated_at.to_datetime < updated_since
        category_id = @category.id
        account_id = @mobihelp_app.account_id
        sql_query = %(SELECT count(*) as count FROM #{FOLDER_TABLE_NAME} f LEFT JOIN #{ARTICLE_TABLE_NAME} a ON f.Id = a.folder_id 
          WHERE (f.updated_at > '#{updated_since}' OR a.updated_at > '#{updated_since}') AND f.account_id = #{account_id} 
          AND a.account_id = #{account_id} AND f.category_id = #{category_id} AND f.is_default = 0 
          AND f.visibility = #{Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]}
          AND a.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]})
          
        result = ActiveRecord::Base.connection.execute(sql_query)
        result_hash = result.fetch_hash
        render_json({:no_update => true}) if result_hash["count"] == 0
      end
    end
  end
end

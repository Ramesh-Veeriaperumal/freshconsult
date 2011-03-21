class HomeController < ApplicationController
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    @categories = current_account.solution_categories
    @forums_categories = current_account.forum_categories
    @posts = recentposts
  end
  
  def get_categories
    @category = Solution::Category.find(:first, :include =>:folders , :conditions =>{:id =>params[:id]})    
     render :partial => "solution_toc", :locals => { :category => @category }
  end
  
  def get_article
    @solution = Solution::Article.find(params[:id])
     render :partial => 'solution_article', :locals => { :article => @solution }
  end
  
  protected
    
    def post_order
      "#{Post.table_name}.created_at#{params[:forum_id] && params[:topic_id] ? nil : " desc"}"
    end
    
    def recentposts
      conditions = []
      [:user_id, :forum_id, :topic_id].each { |attr| conditions << Post.send(:sanitize_sql, ["#{Post.table_name}.#{attr} = ?", params[attr]]) if params[attr] }
      conditions << Post.send(:sanitize_sql, ["#{Post.table_name}.account_id = ?", current_account.id])
      conditions = conditions.empty? ? nil : conditions.collect { |c| "(#{c})" }.join(' AND ')
      Post.find(:all,:conditions => conditions, :order => post_order, :limit =>5 )
    end
  
  
end

class HomeController < ApplicationController
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    @categories = current_account.solution_categories
    @forums_categories = current_account.forum_categories
    @topics = Topic.find(:all,:conditions => ["account_id = ?", current_account.id], :order => "replied_at desc", :limit =>5 )
  end
  
  def get_categories
    @category = Solution::Category.find(:first, :include =>:folders , :conditions =>{:id =>params[:id]})    
     render :partial => "solution_toc", :locals => { :category => @category }
  end
  
  def get_article
    @solution = Solution::Article.find(params[:id])
     render :partial => 'solution_article', :locals => { :article => @solution }
  end
  
  
  
  
end

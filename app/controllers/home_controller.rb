class HomeController < ApplicationController
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    @categories = current_account.solution_categories.all(:include => :folders)
   
  end
  
  
  def get_categories
    
    logger.debug "Folder is is  :::  #{params[:id]}"
    
    @category = Solution::Category.find(:first, :include =>:folders , :conditions =>{:id =>params[:id]})
    
        
     render :partial => "solution_toc", :locals => { :category => @category }
    
  end
  
  def get_article
    
    logger.debug "Folder is is  :::  #{params[:id]}"
    
    @solution = Solution::Article.find(params[:id])
       
     render :partial => 'solution_article', :locals => { :article => @solution } 
    
  end
  
  def search_solution
    #For now, :star has been commented out as wildcard and stopwords don't go together well.
    @articles = Solution::Article.search params[:search_key], 
                                  :with => { :account_id => current_account.id, :is_public => true }#, :star => true
    render :partial => 'solution_search_result', :locals => { :articles => @articles, :key => params[:search_key] } 
  end
  
end

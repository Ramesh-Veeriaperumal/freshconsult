class HomeController < ApplicationController
  def index
    redirect_to helpdesk_dashboard_path if (current_user && current_user.permission?(:manage_tickets))
    
    @folder = Solution::Folder
  end
  
  
  def get_folders
    
    logger.debug "Folder is is  :::  #{params[:id]}"
    
    @folder = Solution::Folder.find(:first, :include =>:categories , :conditions =>{:id =>params[:id]})
    
        
     render :partial => "solution_toc", :locals => { :folder => @folder }
    
  end
  
  def get_article
    
    logger.debug "Folder is is  :::  #{params[:id]}"
    
    @solution = Helpdesk::Article.find(params[:id])
       
     render :partial => 'solution_article', :locals => { :article => @solution } 
    
  end
  
  def search_solution
    
    search_str = params[:search_key]
    
    logger.debug "search_str is #{search_str.inspect}"
    
    search_tokens =  search_str.scan(/\w+/)
    
    @articles = Helpdesk::Article.title_or_body_like_any(search_tokens).is_public(true).limit(10)
    
    render :partial => 'solution_search_result', :locals => { :articles => @articles, :key => search_str } 
    
  end
  
end

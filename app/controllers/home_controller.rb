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
    
    search_str = params[:search_key]
    
    logger.debug "search_str is #{search_str.inspect}"
    
    tokens =  search_str.scan(/\w+/)
    
    search_tokens = tokens-Solution::Article::SEARCH_STOP_WORDS
    
    @articles = Array.new
    
    @articles = Solution::Article.title_or_description_like_any(search_tokens).is_public(true).first(10) unless search_tokens.empty?
    
    render :partial => 'solution_search_result', :locals => { :articles => @articles, :key => search_str } 
    
  end
  
end

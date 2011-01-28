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
  
end

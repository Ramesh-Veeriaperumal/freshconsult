class Helpdesk::DropboxesController < ApplicationController  

  include HelpdeskControllerMethods
  
  skip_before_filter :check_privilege
  before_filter :check_destroy_permission, :only => [:destroy]

  protected
  	
  	def scoper
    	current_account.dropboxes
  	end 

end
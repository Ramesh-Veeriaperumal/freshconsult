class Helpdesk::DropboxesController < ApplicationController  

  include HelpdeskControllerMethods

  before_filter :check_destroy_permission, :only => [:destroy]

  protected
  	
  	def scoper
    	current_account.dropboxes
  	end 

end
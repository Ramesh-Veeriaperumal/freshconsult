class Helpdesk::CloudFilesController < ApplicationController  

  include HelpdeskControllerMethods
  
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :check_destroy_permission, :only => [:destroy]

  protected

    def scoper
      current_account.cloud_files
    end 

end
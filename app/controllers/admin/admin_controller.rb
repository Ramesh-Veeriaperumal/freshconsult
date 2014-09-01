class Admin::AdminController < ApplicationController
  # 1. I have not added any authorization for this controller
  # => i dont think it is being used anywhere
  before_filter :set_selected_tab
  
  protected
    
    def set_selected_tab
        @selected_tab = :admin
    end
    
end
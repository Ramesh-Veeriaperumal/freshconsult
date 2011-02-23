class Admin::AdminController < ApplicationController
  before_filter { |c| c.requires_permission :manage_users }
  before_filter :set_selected_tab
  
  protected
    
    def set_selected_tab
        @selected_tab = 'Admin'
    end
    
end
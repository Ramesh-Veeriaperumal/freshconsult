class Admin::EmailConfigsController < ApplicationController
  include ModelControllerMethods
  
  before_filter :set_selected_tab
  
  def index
    @email_configs = scoper.all
    @groups = current_account.groups    
  end
  
  def new
    @groups = current_account.groups
    render :partial => "email_form", :locals => { :type => "new" }
  end

  def edit
    @groups = current_account.groups
    render :partial => "email_form", :object => scoper.find(params[:id]), :locals => { :type => "edit" }
  end
  
  protected
    def scoper
      current_account.email_configs
    end

    def set_selected_tab
      @selected_tab = "Admin"
    end
end

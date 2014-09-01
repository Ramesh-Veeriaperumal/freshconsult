class SubscriptionAdmin::SubscriptionPlansController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  before_filter :set_selected_tab  
  
  protected  
    def load_object
      @obj = @subscription_plan = SubscriptionPlan.find_by_name(params[:id])
    end    
    
    def set_selected_tab
        @selected_tab = :plans
     end

    def check_admin_user_privilege
      if !(current_user and  current_user.has_role?(:plans))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
end

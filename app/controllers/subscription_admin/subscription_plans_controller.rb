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
end

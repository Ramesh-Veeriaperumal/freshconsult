class SubscriptionAdmin::SubscriptionDiscountsController < ApplicationController
  skip_before_filter :check_account_state
  include ModelControllerMethods
  include AdminControllerMethods        
  before_filter :set_selected_tab    
  
  protected
  def set_selected_tab
     @selected_tab = :discounts
  end
end

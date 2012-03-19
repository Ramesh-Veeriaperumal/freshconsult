class SubscriptionAdmin::SubscriptionAffiliatesController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  before_filter :set_selected_tab  
  
  protected
    def set_selected_tab
       @selected_tab = :affiliates
    end
end
class SubscriptionAdmin::SubscriptionDiscountsController < ApplicationController
  skip_before_filter :check_account_state
  include ModelControllerMethods
  include AdminControllerMethods
end

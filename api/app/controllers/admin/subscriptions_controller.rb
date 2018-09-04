module Admin
  class SubscriptionsController < ApiApplicationController
    include HelperConcern
    decorate_views
    def load_object
      @item = Account.current.subscription
    end
  end
end

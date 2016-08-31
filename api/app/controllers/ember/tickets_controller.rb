module Ember
  class TicketsController < ::TicketsController
    before_filter :ticket_permission?, only: [:spam]
    
    def index
      super
      response.api_meta = { :count => tickets_filter.count }
      #TODO-EMBERAPI Optimize the way we fetch the count
      render 'tickets/index'
    end

    def resource
      :"ember/ticket"
    end

    def spam
      @item.spam = true
      store_dirty_tags(@item)
      @item.save
      head 204
    end
  end
end

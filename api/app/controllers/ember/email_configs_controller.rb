module Ember
  class EmailConfigsController < ::ApiEmailConfigsController
    def index
      super
      response.api_meta = { count: @items_count }
    end
  end
end

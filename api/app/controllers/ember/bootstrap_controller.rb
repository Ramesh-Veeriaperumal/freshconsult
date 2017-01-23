module Ember
  class BootstrapController < ApiApplicationController

    COLLECTION_RESPONSE_FOR = []
    def index
      response.api_meta = {
        csrf_token: self.send(:form_authenticity_token)
      }
    end
  end
end

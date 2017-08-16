module Ember
  class BootstrapController < ApiApplicationController
    COLLECTION_RESPONSE_FOR = [].freeze

    def index
      response.api_meta = {
        csrf_token: send(:form_authenticity_token)
      }
    end
  end
end

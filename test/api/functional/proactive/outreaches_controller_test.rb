require_relative '../../test_helper'
module Proactive
  class OutreachesControllerTest < ActionController::TestCase
    include ::Proactive::ProactiveJwtAuth
    def setup
      super
      Account.find(Account.current.id).make_current
    end
    # add methods here
  end
end

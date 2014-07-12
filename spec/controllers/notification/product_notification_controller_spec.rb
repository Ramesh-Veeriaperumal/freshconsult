require 'spec_helper'

describe Notification::ProductNotificationController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
  end  

  it "should render the index" do
    get :index
    response.should render_template("notification/_product_notification.html.erb")
  end
end
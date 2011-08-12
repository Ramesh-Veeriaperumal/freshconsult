require 'spec_helper'

describe "/support/company_tickets/index" do
  before(:each) do
    render 'support/company_tickets/index'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/support/company_tickets/index])
  end
end

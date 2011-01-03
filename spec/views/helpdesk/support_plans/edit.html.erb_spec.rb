require 'spec_helper'

describe "/helpdesk/support_plans/edit" do
  before(:each) do
    render 'helpdesk/support_plans/edit'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/helpdesk/support_plans/edit])
  end
end

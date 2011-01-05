require 'spec_helper'

describe "/helpdesk/sla_policies/edit" do
  before(:each) do
    render 'helpdesk/sla_policies/edit'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/helpdesk/sla_policies/edit])
  end
end

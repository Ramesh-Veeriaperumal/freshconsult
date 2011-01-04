require 'spec_helper'

describe "/virtual_agents/update" do
  before(:each) do
    render 'virtual_agents/update'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/virtual_agents/update])
  end
end

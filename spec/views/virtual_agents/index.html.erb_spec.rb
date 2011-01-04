require 'spec_helper'

describe "/virtual_agents/index" do
  before(:each) do
    render 'virtual_agents/index'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/virtual_agents/index])
  end
end

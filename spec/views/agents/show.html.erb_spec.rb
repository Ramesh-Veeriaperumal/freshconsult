require 'spec_helper'

describe "/agents/show" do
  before(:each) do
    render 'agents/show'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/agents/show])
  end
end

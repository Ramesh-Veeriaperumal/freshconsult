require 'spec_helper'

describe "/solution/folders/show" do
  before(:each) do
    render 'solution/folders/show'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/solution/folders/show])
  end
end

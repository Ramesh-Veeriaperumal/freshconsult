require 'spec_helper'

describe "/solution/categories/create" do
  before(:each) do
    render 'solution/categories/create'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/solution/categories/create])
  end
end

require 'spec_helper'

describe "/profiles/create" do
  before(:each) do
    render 'profiles/create'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/profiles/create])
  end
end

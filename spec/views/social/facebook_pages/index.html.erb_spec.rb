require 'spec_helper'

describe "/social/facebook_pages/index" do
  before(:each) do
    render 'social/facebook_pages/index'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/social/facebook_pages/index])
  end
end

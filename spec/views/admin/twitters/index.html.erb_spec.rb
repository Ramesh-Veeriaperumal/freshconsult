require 'spec_helper'

describe "/admin/twitter/index" do
  before(:each) do
    render 'admin/twitter/index'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/admin/twitter/index])
  end
end

require 'spec_helper'

describe "/admin/products/new" do
  before(:each) do
    render 'admin/products/new'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/admin/products/new])
  end
end

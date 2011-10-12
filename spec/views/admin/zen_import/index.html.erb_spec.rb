require 'spec_helper'

describe "/admin/zen_import/index" do
  before(:each) do
    render 'admin/zen_import/index'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/admin/zen_import/index])
  end
end

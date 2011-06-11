require 'spec_helper'

describe "/admin/canned_responses/new" do
  before(:each) do
    render 'admin/canned_responses/new'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/admin/canned_responses/new])
  end
end

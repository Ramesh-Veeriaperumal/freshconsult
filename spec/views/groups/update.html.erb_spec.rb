require 'spec_helper'

describe "/groups/update" do
  before(:each) do
    render 'groups/update'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/groups/update])
  end
end

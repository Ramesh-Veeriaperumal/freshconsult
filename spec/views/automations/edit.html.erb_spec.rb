require 'spec_helper'

describe "/automations/edit" do
  before(:each) do
    render 'automations/edit'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/automations/edit])
  end
end

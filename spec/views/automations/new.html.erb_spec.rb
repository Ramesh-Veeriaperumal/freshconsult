require 'spec_helper'

describe "/automations/new" do
  before(:each) do
    render 'automations/new'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/automations/new])
  end
end

require 'spec_helper'

describe "/va_rules/edit" do
  before(:each) do
    render 'va_rules/edit'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/va_rules/edit])
  end
end

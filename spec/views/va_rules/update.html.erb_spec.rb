require 'spec_helper'

describe "/va_rules/update" do
  before(:each) do
    render 'va_rules/update'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/va_rules/update])
  end
end

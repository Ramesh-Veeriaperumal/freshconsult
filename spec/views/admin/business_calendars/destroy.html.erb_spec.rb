require 'spec_helper'

describe "/admin/business_calendars/destroy" do
  before(:each) do
    render 'admin/business_calendars/destroy'
  end

  #Delete this example and add some real ones or delete this file
  it "should tell you where to find the file" do
    response.should have_tag('p', %r[Find me in app/views/admin/business_calendars/destroy])
  end
end

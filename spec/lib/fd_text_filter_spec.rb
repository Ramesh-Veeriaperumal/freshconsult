require 'spec_helper'

RSpec.describe Integrations::FDTextFilter do
  include Integrations::FDTextFilter


  it 'should escape html' do
  	resource = "<p> Test description </p>"
    escape_html(resource)
    resource.should_not be_nil
  end

  it 'should encode html' do
    resource = "<p> Test description </p>"
    encode_html(resource)
    resource.should_not be_nil
  end

end
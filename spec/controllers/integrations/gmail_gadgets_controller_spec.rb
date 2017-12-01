require 'spec_helper'

describe Integrations::GmailGadgetsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @env = Rails.env
  end

  after(:each) do
    if Rails.env.development?
      class << @env
        remove_method(:development?)
      end
    elsif Rails.env.staging?
      class << @env
        remove_method(:staging?)
      end
    elsif Rails.env.production?
      class << @env
        remove_method(:production?)
      end
    end
  end

   before(:each) do
    login_admin
    @request.host = @account.full_domain
  end

  it "should get correct spec for development" do
    def @env.development? 
      true;
    end
    get :spec, :format => "xml"
    result = parse_xml(response)
    result.has_key?('Module').should eql(true)
  end

  it "should get correct spec for staging environment" do
    def @env.staging? 
      true;
    end
    get :spec, :format => "xml"
    result = parse_xml(response)
    result.has_key?('Module').should eql(true)
  end

  it "should get correct spec for production environment" do
    def @env.production? 
      true;
    end
    @account.update_attributes(:ssl_enabled => false)
    get :spec, :format => "xml"
    result = parse_xml(response)
    result.has_key?('Module').should eql(true)
  end
end


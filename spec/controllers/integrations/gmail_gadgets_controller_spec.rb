require 'spec_helper'

describe Integrations::GmailGadgetsController do
  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @env = Rails.env
  end

  after(:each) do
    if @env.respond_to?(:development?)
      class << @env
        remove_method(:development?)
      end
    elsif @env.respond_to?(:staging?)
      class << @env
        remove_method(:staging?)
      end
    elsif @env.respond_to?(:production?)
      class << @env
        remove_method(:production?)
      end
    end
  end

   before(:each) do
    login_admin
    @request.host = RSpec.configuration.account.full_domain
  end

  it "should get correct spec for development" do
    def @env.development? 
      true;
    end
    get :spec, :format => "xml"
    response.body.should have_tag("Module", /script/)
  end

  it "should get correct spec for staging environment" do
    def @env.staging? 
      true;
    end
    get :spec, :format => "xml"
    response.body.should have_tag("Module", /script/)
  end

  it "should get correct spec for production environment" do
    def @env.production? 
      true;
    end
    RSpec.configuration.account.update_attributes(:ssl_enabled => false)
    get :spec, :format => "xml"
    response.body.should have_tag("Module", /script/)
  end
end


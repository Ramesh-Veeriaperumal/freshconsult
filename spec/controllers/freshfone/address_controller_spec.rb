require 'spec_helper'

describe Freshfone::AddressController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'should create a new address for new country' do
    name = Faker::Name.name
    params = { :friendly_name => name,
        :business_name => name,
        :address => Faker::Address.street_address,
        :city => Faker::Address.city,
        :state => Faker::Address.state,
        :postal_code => Faker::Address.postcode,
        :country => 'DE'
    }
    post :create, params
    ff_address_inspect('DE').should be_eql(true)
    json.should be_eql({:success => true, :errors => []})
  end

  it 'should not create a new address for new country without name' do
    name = Faker::Name.name
    params = { 
        :address => Faker::Address.street_address,
        :city => Faker::Address.city,
        :state => Faker::Address.state,
        :postal_code => Faker::Address.postcode,
        :country => 'DE'
    }
    post :create, params
    ff_address_inspect('DE').should be_eql(false)
    json.should be_eql({:success => false, :errors => ["Business name can't be blank"]})
  end

end
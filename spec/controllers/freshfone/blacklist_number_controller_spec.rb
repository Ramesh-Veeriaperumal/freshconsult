require 'spec_helper'

describe Freshfone::BlacklistNumberController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = RSpec.configuration.account.full_domain
    log_in(@agent)
  end

  it 'should blacklist number on create action' do
    number = Faker::PhoneNumber.phone_number
    post :create, {"blacklist_number"=>{"number"=>number}}
    blacklist = RSpec.configuration.account.freshfone_blacklist_numbers.find_by_number(number)
    blacklist.should_not be_nil
    blacklist.destroy
  end

  it 'should not blacklist number on failed creation' do
    number = Faker::PhoneNumber.phone_number
    Freshfone::BlacklistNumber.any_instance.stubs(:save).returns(false)
    post :create, {"blacklist_number"=>{"number"=>number}}
    blacklist = RSpec.configuration.account.freshfone_blacklist_numbers.find_by_number(number)
    blacklist.should be_nil
  end

  it 'should whitelist number on destroy action' do
    number = Faker::PhoneNumber.phone_number
    RSpec.configuration.account.freshfone_blacklist_numbers.build({:number => number}).save
    post :destroy, {:id => number}
    blacklist = RSpec.configuration.account.freshfone_blacklist_numbers.find_by_number(number)
    blacklist.should be_nil
  end

  it 'should not whitelist number on destroy action failure' do
    number = Faker::PhoneNumber.phone_number
    RSpec.configuration.account.freshfone_blacklist_numbers.build({:number => number}).save
    Freshfone::BlacklistNumber.any_instance.stubs(:destroy).returns(false)
    post :destroy, {:id => number}
    blacklist = RSpec.configuration.account.freshfone_blacklist_numbers.find_by_number(number)
    blacklist.should_not be_nil
  end


end
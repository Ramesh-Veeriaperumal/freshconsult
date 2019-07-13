require_relative '../../../api/unit_test_helper'

class SalesforceServiceTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    super
    Account.unstub(:current)
  end

  def test_receive_install
    VaRule.any_instance.stubs(:save!).returns(true)
    app = Integrations::InstalledApplication.new
    inst = ::IntegrationServices::Services::SalesforceService.new(app, { type: 'test' }, {}).receive_install
    assert_equal true, inst.present?
  end

  def test_instance_url
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { instance_url: 'testurl' }.stringify_keys!)
    app = Integrations::InstalledApplication.new
    inst = ::IntegrationServices::Services::SalesforceService.new(app, { type: 'test' }, {}).instance_url
    assert_equal 'testurl', inst
  end

  def test_receive_create_custom_object
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { salesforce_sync_option: 0 }.stringify_keys!)
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:check_fields_synced?).returns(false)
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.stubs(:find).returns(records: [{ Id: 1 }])
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.stubs(:create).returns(records: [{ Id: 1 }])
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:create).returns({ id: 5 }.stringify_keys!)
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:find).returns({ records: [{ Name: 'Test name', Id: 1, AccountId: 1, Account: { Name: 'freshdesk unknown company'}.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    Helpdesk::Ticket.any_instance.stubs(:requester).returns(Account.first.contacts.first)
    Helpdesk::Ticket.any_instance.stubs(:requester).returns(Account.first.users.first)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:find_user).returns({})
    app = Integrations::InstalledApplication.new
    cust_obj = ::IntegrationServices::Services::SalesforceService.new(app, { data_object: Account.first.tickets.first }, {}).receive_create_custom_object
    assert_equal nil, cust_obj
  end

  def test_receive_link_opportunity
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:create).returns(true)
    app = Integrations::InstalledApplication.new
    link = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_link_opportunity
    assert_equal true, link
  end

  def test_receive_link_opportunity_error
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:create).raises(Exception.new('exception'))
    app = Integrations::InstalledApplication.new
    link = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_link_opportunity
    assert_equal 'Error in linking the ticket with the salesforce opportunity', link[:message]
  end

  def test_receive_create_opportunity
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.any_instance.stubs(:create).returns(true)
    app = Integrations::InstalledApplication.new
    create_opp = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_create_opportunity
    assert_equal true, create_opp
  end

  def test_receive_create_opportunity_error
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.any_instance.stubs(:create).raises(IntegrationServices::Errors::RemoteError.new('exception'))
    app = Integrations::InstalledApplication.new
    create_opp = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_create_opportunity
    assert_equal 'exception', create_opp[:message]
  end

  def test_receive_unlink_opportunity
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:where).returns([Integrations::IntegratedResource.new])
    Integrations::IntegratedResource.any_instance.stubs(:destroy).returns(true)
    app = Integrations::InstalledApplication.new
    unlink_opp = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_unlink_opportunity
    assert_equal true, unlink_opp
  end

  def test_receive_unlink_opportunity_error
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::IntegratedResource.new)
    Integrations::IntegratedResource.any_instance.stubs(:where).returns([Integrations::IntegratedResource.new])
    Integrations::IntegratedResource.any_instance.stubs(:destroy).raises(Exception.new('exception'))
    app = Integrations::InstalledApplication.new
    unlink_opp = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_unlink_opportunity
    assert_equal 'Error in unlinking the ticket with the salesforce opportunity', unlink_opp[:message]
  end

  def test_receive_update_custom_object
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { salesforce_sync_option: 0 }.stringify_keys!)
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:check_fields_synced?).returns(false)
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:find).returns({ records: [{ Name: 'Test name', Id: 1, AccountId: 1, Account: { Name: 'freshdesk unknown company'}.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:find).returns({ records: [{ Name: 'Test name', Id: 1, AccountId: 1, Account: { Name: 'freshdesk unknown company'}.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    Helpdesk::Ticket.any_instance.stubs(:requester).returns(Account.first.contacts.first)
    Helpdesk::Ticket.any_instance.stubs(:requester).returns(Account.first.users.first)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:find_user).returns({})
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:update).returns(nil)
    app = Integrations::InstalledApplication.new
    cust_obj = ::IntegrationServices::Services::SalesforceService.new(app, { data_object: Account.first.tickets.first }, {}).receive_update_custom_object
    assert_equal nil, cust_obj
  end

  def test_receive_update_custom_object_no_records
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { salesforce_sync_option: 0 }.stringify_keys!)
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.stubs(:find).returns(records: [{ Id: 1 }])
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.stubs(:create).returns(records: [{ Id: 1 }])
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:check_fields_synced?).returns(false)
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:find).returns({})
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:find).returns({ records: [{ Name: 'Test name', Id: 1, AccountId: 1, Account: { Name: 'freshdesk unknown company'}.stringify_keys! }.stringify_keys!] }.stringify_keys!)
    Helpdesk::Ticket.any_instance.stubs(:requester).returns(Account.first.contacts.first)
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:create).returns({ id: 5 }.stringify_keys!)
    Helpdesk::Ticket.any_instance.stubs(:requester).returns(Account.first.users.first)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:find_user).returns({})
    IntegrationServices::Services::Salesforce::SalesforceCustomObjectResource.any_instance.stubs(:update).returns(nil)
    app = Integrations::InstalledApplication.new
    cust_obj = ::IntegrationServices::Services::SalesforceService.new(app, { data_object: Account.first.tickets.first }, {}).receive_update_custom_object
    assert_equal nil, cust_obj
  end

  def test_receive_contact_fields
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.stubs(:get_fields).returns('contact field')
    app = Integrations::InstalledApplication.new
    cf = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_contact_fields
    assert_equal 'contact field', cf
  end

  def test_receive_lead_fields
    IntegrationServices::Services::Salesforce::SalesforceLeadResource.any_instance.stubs(:get_fields).returns('lead res')
    app = Integrations::InstalledApplication.new
    leadres = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_lead_fields
    assert_equal 'lead res', leadres
  end

  def test_receive_account_fields
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.stubs(:get_fields).returns('acc')
    app = Integrations::InstalledApplication.new
    ac = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_account_fields
    assert_equal 'acc', ac
  end

  def test_receive_opportunity_fields
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.any_instance.stubs(:get_fields).returns('opp')
    app = Integrations::InstalledApplication.new
    opp = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_opportunity_fields
    assert_equal 'opp', opp
  end

  def test_receive_opportunity_stage_field
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.any_instance.stubs(:stage_name_picklist_values).returns('opp')
    app = Integrations::InstalledApplication.new
    opp = ::IntegrationServices::Services::SalesforceService.new(app, {}, {}).receive_opportunity_stage_field
    assert_equal 'opp', opp
  end
end
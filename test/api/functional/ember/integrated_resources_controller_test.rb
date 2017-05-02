require_relative '../../test_helper'

class Ember::IntegratedResourcesControllerTest < ActionController::TestCase
  include TicketsTestHelper
  include InstalledApplicationsTestHelper
  include TimeEntriesTestHelper
  include IntegratedResourcesTestHelper

  def setup
    super
    mkt_place = Account.current.features?(:marketplace)
    Account.current.features.marketplace.destroy if mkt_place
    Account.current.reload
    @api_params = { version: 'private' }
  end

  def wrap_cname(params)
    { integrated_resources: params }
  end

  def test_create_integ_resource
    t1 = create_ticket
    harvest_app = create_application('harvest')
    agent = add_test_agent(@account)
    time_sheet = create_time_entry(billable: false, ticket_id: t1.id, agent_id: agent.id, executed_at: 19.days.ago.iso8601)
    application = Integrations::Application.find_by_name('harvest')
    resource_params = {
      application_id: application.id,
      integrated_resource: {
        remote_integratable_id: 'ROSH-100',
        local_integratable_id: time_sheet.id,
        installed_application_id: harvest_app.id,
        local_integratable_type: 'Helpdesk::TimeSheet'
      }
    }
    post :create, construct_params(@api_params.merge(resource_params))
    assert_response 200
    match_json(integrated_resource_pattern(Integrations::IntegratedResource.first))
  end

  def test_show_integ_resource
    resource = Integrations::IntegratedResource.first
    get :show, construct_params(version: 'private', id: resource.id)
    assert_response 200
    match_json(integrated_resource_pattern(resource))
  end

  def test_create_integ_resource_with_ticket_type
    t2 = create_ticket
    salesforce_app = create_application('salesforce_v2')
    app = Integrations::Application.find_by_name('salesforce_v2')
    sf_params = {
      application_id: app.id,
      integrated_resource: {
        remote_integratable_id: 'ROSH-2000',
        local_integratable_id: t2.display_id,
        installed_application_id: salesforce_app.id,
        local_integratable_type: 'Helpdesk::Ticket'
      }
    }
    post :create, construct_params(@api_params.merge(sf_params))
    assert_response 200
    match_json(integrated_resource_pattern(Integrations::IntegratedResource.last))
  end

  def test_create_integ_resource_with_wrong_ticket_id
    t3 = create_ticket
    sf_v1_installedapp = create_application('salesforce')
    sf_v1_app = Integrations::Application.find_by_name('salesforce')
    sf_params1 = {
      application_id: sf_v1_app.id,
      integrated_resource: {
        remote_integratable_id: 'ROSH-1000',
        local_integratable_id: Helpdesk::Ticket.last.display_id + 100,
        installed_application_id: sf_v1_installedapp.id,
        local_integratable_type: 'Helpdesk::Ticket'
      }
    }
    post :create, construct_params({ version: 'private' }.merge(sf_params1))
    assert_response 404
  end

  def test_create_integ_resource_with_invalid_params
    t4 = create_ticket
    workflow_app = create_application('workflow_max')
    agent1 = add_test_agent(@account)
    time_sheet1 = create_time_entry(billable: false, ticket_id: t4.id, agent_id: agent1.id, executed_at: 19.days.ago.iso8601)
    application1 = Integrations::Application.find_by_name('workflow_max')
    resource_params = {
      application_id: application1.id,
      integrated_resource: {
        remote_integratable_id: 'aaaa',
        local_integratable_id: '',
        installed_application_id: workflow_app.id,
        local_integratable_type: 'Helpdesk::TimeSheet'
      }
    }
    post :create, construct_params(@api_params.merge(resource_params))
    assert_response 400
  end

  def test_index_with_installed_and_integratable_id
    app = Integrations::Application.find_by_name('harvest')
    harvest_app = Account.current.installed_applications.find_by_application_id(app.id)
    timesheet = Helpdesk::TimeSheet.find_by_id(1)
    get :index, controller_params({ version: 'private', installed_application_id: harvest_app.id, local_integratable_id: timesheet.id }, true)
    assert_response 200
  end

  def test_index_with_ticket_type
    t5 = create_ticket
    app = Integrations::Application.find_by_name('salesforce_v2')
    installed_app = Account.current.installed_applications.find_by_application_id(app.id)
    get :index, controller_params({ version: 'private', installed_application_id: installed_app.id, local_integratable_id: t5.display_id, local_integratable_type: 'ticket' }, true)
    assert_response 200
  end

  def test_index_with_empty_response
    app = Integrations::Application.find_by_name('harvest')
    harvest_app = Account.current.installed_applications.find_by_application_id(app.id)
    timesheet = Helpdesk::TimeSheet.find_by_id(1)
    get :index, controller_params({ version: 'private', installed_application_id: harvest_app.id, local_integratable_id: timesheet.id + 100 }, true)
    assert_response 200
    assert_equal '[]', response.body
  end

  def test_delete
    t6 = create_ticket
    app = Integrations::Application.find_by_name('salesforce_v2')
    installed_app = Account.current.installed_applications.find_by_application_id(app.id)
    sf_params = {
      application_id: app.id,
      integrated_resource: {
        remote_integratable_id: 'OPPORTUNITY-1111',
        local_integratable_id: t6.display_id,
        installed_application_id: installed_app.id,
        local_integratable_type: 'Helpdesk::Ticket'
      }
    }
    post :create, construct_params(@api_params.merge(sf_params))
    assert_response 200
    integ_resource_id = Integrations::IntegratedResource.last
    delete :destroy, construct_params(@api_params, false).merge(id: integ_resource_id.id)
    assert_response 204
    refute scoper.exists?(integ_resource_id.id)
  end

  def scoper
    Integrations::IntegratedResource
  end
end

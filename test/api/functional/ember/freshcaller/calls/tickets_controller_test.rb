# frozen_string_literal: true

require_relative '../../../../test_helper'
['tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class Ember::Freshcaller::Calls::TicketsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper

  def setup
    super
    @private_api = true
    Sidekiq::Worker.clear_all
    MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
    Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
    Account.current.reload
    @account.sections.map(&:destroy)
    @account.add_feature :scenario_automation
  end

  def teardown
    super
    Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
  end

  def wrap_cname(params)
    query_params = params[:query_params]
    cparams = params.clone
    cparams.delete(:query_params)
    return query_params.merge(ticket: cparams) if query_params

    { ticket: cparams }
  end

  def test_show_with_invalid_fc_call_id
    Account.stubs(:current).returns(Account.first)
    get :show, controller_params(version: 'private', fc_call_id: Faker::Number.number(2))
    assert_response 404
  ensure
    Account.unstub(:current)
  end

  def test_show_with_valid_fc_call_id_but_no_associated_ticket
    Account.stubs(:current).returns(Account.first)
    fc_call_id = Faker::Number.number(3).to_i
    Account.current.freshcaller_calls.new(fc_call_id: fc_call_id).save
    get :show, controller_params(version: 'private', id: fc_call_id)
    assert_response 404
  ensure
    Account.current.freshcaller_calls.find_by_fc_call_id(fc_call_id).destroy
    Account.unstub(:current)
  end

  def test_show_with_valid_fc_call_id_and_with_associated_ticket
    Account.stubs(:current).returns(Account.first)
    fc_call_id = Faker::Number.number(3).to_i
    fc_call = Account.current.freshcaller_calls.new(fc_call_id: fc_call_id)
    fc_call.save!
    ticket = create_ticket
    ticket.freshcaller_call = fc_call
    ticket.save!
    get :show, controller_params(version: 'private', id: fc_call_id)
    assert_response 200
    match_json(ticket_show_pattern(ticket.reload))
  ensure
    ticket.destroy
    fc_call.destroy
    Account.unstub(:current)
  end
end

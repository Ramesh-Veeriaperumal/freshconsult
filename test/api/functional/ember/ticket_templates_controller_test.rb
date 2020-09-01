require_relative '../../test_helper'
['ticket_template_helper.rb', 'group_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"

module Ember
  class TicketTemplatesControllerTest < ActionController::TestCase
    include GroupHelper
    include TicketTemplateHelper
    include TicketTemplatesTestHelper
    include AgentHelper

    def setup
      super
      before_all
    end

    def before_all
      @file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      @account = Account.first.make_current
      @agent = get_admin
      @groups = []
      @current_user = User.current
      @account.ticket_templates.destroy_all
      3.times { @groups << create_group(@account) }
    end

    def test_simple_index_for_primary_templates
      enable_adv_ticketing(%i(parent_child_tickets)) do
        10.times do
          create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        end
        get :index, controller_params(version: 'private', type: :prime, filter: :accessible)
        assert_response 200
        match_json(private_api_prime_templates_index_pattern)
      end
    end

    def test_simple_index_for_primary_templates_without_feature
      Account.any_instance.stubs(:tkt_templates_enabled?).returns(false)
      Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(false)
      10.times do
        create_tkt_template(name: Faker::Name.name,
                            association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                            account_id: @account.id,
                            accessible_attributes: {
                              access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                            })
      end
      get :index, controller_params(version: 'private', type: :prime, filter: :accessible)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Ticket Templates'))
      Account.any_instance.unstub(:tkt_templates_enabled?)
      Account.any_instance.unstub(:parent_child_tickets_enabled?)
    end

    def test_index_with_multiple_groups
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      login_as(new_agent.user)
      # create groups
      groups = create_groups(Account.current, options = { count: 20 })
      group_ids = groups.map(&:id)

      # assign group to agent
      groups.each do |group|
        Account.current.agent_groups.create(user_id: new_agent.user.id, group_id: group.id)
      end
      tts = []
      25.times do
        tts << create_tkt_template(name: Faker::Name.name,
                                   association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                   account_id: @account.id,
                                   accessible_attributes: {
                                     access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],
                                     group_ids: group_ids
                                   })
      end
      get :index, controller_params(version: 'private', type: :prime, filter: :accessible)
      tt_ids = tts.map(&:id)
      assert_response 200
      assert (tts.map(&:id) - JSON.parse(response.body).map { |res| res['id'] }).count.zero?, "Ticket templates count mismatch, Missing templates: #{(tts.map(&:id) - JSON.parse(response.body).map { |res| res['id'] })}"
    ensure
      new_agent.destroy
      groups.map(&:destroy)
      tts.map(&:destroy)
    end

    def test_index_with_multiple_groups_higher_than_limit
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      login_as(new_agent.user)
      # create groups
      groups = create_groups(Account.current, options = { count: 20 })
      group_ids = groups.map(&:id)

      # assign group to agent
      groups.each do |group|
        Account.current.agent_groups.create(user_id: new_agent.user.id, group_id: group.id)
      end
      tts = []
      400.times do
        tts << create_tkt_template(name: Faker::Name.name,
                                   association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                   account_id: @account.id,
                                   accessible_attributes: {
                                     access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],
                                     group_ids: group_ids
                                   })
      end
      get :index, controller_params(version: 'private', type: :prime, filter: :accessible)
      tt_ids = tts.map(&:id)
      assert_response 200
      assert !(tts.map(&:id) - JSON.parse(response.body).map { |res| res['id'] }).count.zero?, "Ticket templates count doesn't mismatch"
    ensure
      new_agent.destroy
      groups.map(&:destroy)
      tts.map(&:destroy)
    end

    def test_show_without_parent_child_feature
      Account.any_instance.stubs(:tkt_templates_enabled?).returns(false)
      Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(false)
      @template = create_tkt_template(name: Faker::Name.name,
                                      association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                      account_id: @account.id,
                                      accessible_attributes: {
                                        access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                      })
      get :show, controller_params(version: 'private', id: @template.id)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Ticket Templates'))
      Account.any_instance.unstub(:tkt_templates_enabled?)
      Account.any_instance.unstub(:parent_child_tickets_enabled?)
    end

    def test_show_with_valid_params_for_parent_template
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        child_template = create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        get :show, controller_params(version: 'private', id: @template.id, type: 'only_parent')
        assert_response 200
        match_json(to_hash_and_child_template_pattern)
      end
    end

    def test_show_without_type_for_parent_template
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })

        child_template = create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        child_template.build_parent_assn_attributes(@template.id)
        child_template.save
        get :show, controller_params(version: 'private', id: @template.id)
        assert_response 200
        match_json(private_api_show_pattern)
      end
    end

    def test_show_without_invalid_type_for_parent_template
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        child_template = create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        child_template.build_parent_assn_attributes(@template.id)
        child_template.save
        get :show, controller_params(version: 'private', id: @template.id, type: "abcxyz")
        assert_response 200
        match_json(private_api_show_pattern)
      end
    end

    def test_simple_index_for_primary_templates_with_parent_templates
      enable_adv_ticketing(%i(parent_child_tickets)) do
        3.times do
          create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        end
        3.times do
          create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        end
        get :index, controller_params(version: 'private', type: :prime, filter: :accessible)
        assert_response 200
        match_json(private_api_prime_templates_index_pattern)
      end
    end

    def test_simple_accessible_for_ticket_templates
      enable_adv_ticketing(%i(parent_child_tickets)) do
        5.times do
          create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                              account_id: @account.id,
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        end
        get :index, controller_params(version: 'private', filter: :accessible)
        assert_response 200
        match_json(private_api_ticket_templates_index_pattern)
      end
    end

    def test_show
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                        account_id: @account.id,
                                        accessible_attributes: {
                                          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                        })
        get :show, controller_params(version: 'private', id: @template.id)
        match_json(private_api_show_pattern)
      end
    end

    def test_accessibility_of_personal_template
      agent = add_test_agent(@account)
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                                        account_id: @account.id,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                        accessible_attributes: { access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users], user_ids: [agent.id] })
        login_as(agent)
        get :show, controller_params(version: 'private', id: @template.id)
        match_json(private_api_show_pattern)
      end
      login_as(@current_user)
      @template.destroy
    end

    def test_non_accessibility_of_personal_template
      agent = add_test_agent(@account)
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                                        account_id: @account.id,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                        accessible_attributes: { access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users], user_ids: [@current_user.id] })
        login_as(agent)
        get :show, controller_params(version: 'private', id: @template.id)
        assert_response 403
      end
      login_as(@current_user)
      @template.destroy
    end

    # Test this after adding keys
    def test_show_with_attachment
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                                        account_id: @account.id,
                                        attachments: [{
                                          resource: @file,
                                          description: ''
                                        }],
                                        accessible_attributes: {
                                          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                        })
        old_time_zone = Time.zone.name
        Time.zone = 'UTC'
        get :show, controller_params(version: 'private', id: @template.id)
        match_json(private_api_show_pattern)
        Time.zone = old_time_zone
      end
    end

    def test_show_with_non_existent_ids
      enable_adv_ticketing(%i(parent_child_tickets)) do
        get :show, controller_params(version: 'private', id: 9999)
        assert_response 404
      end
    end

    def test_show_with_parent_template_with_child
      enable_adv_ticketing(%i(parent_child_tickets)) do
        @template = create_tkt_template(name: Faker::Name.name,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                        account_id: @account.id,
                                        accessible_attributes: {
                                          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                        })

        child_template = create_tkt_template(name: Faker::Name.name,
                                             association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                             account_id: @account.id,
                                             accessible_attributes: {
                                               access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                             })

        child_template.build_parent_assn_attributes(@template.id)
        child_template.save
        get :show, controller_params(version: 'private', id: @template.id)
        assert_response 200
        match_json(private_api_show_pattern)
        child_template.destroy
      end
    end

    def test_show_with_parent_template_with_multiple_children
      enable_adv_ticketing(%i(parent_child_tickets)) do
        child_templates = []
        @template = create_tkt_template(name: Faker::Name.name,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                        account_id: @account.id,
                                        accessible_attributes: {
                                          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                        })
        5.times.each do
          child_template = create_tkt_template(name: Faker::Name.name,
                                               association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                               account_id: @account.id,
                                               accessible_attributes: {
                                                 access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                               })

          child_template.build_parent_assn_attributes(@template.id)
          child_template.save
          child_templates << child_template
        end
        get :show, controller_params(version: 'private', id: @template.id)
        assert_response 200
        match_json(private_api_show_pattern)
        child_templates.each do |child_template|
          child_template.destroy
        end
      end
    end

    def test_ticket_templates_with_source
      enable_adv_ticketing(%i[parent_child_tickets]) do
        5.times do
          create_tkt_template(name: Faker::Name.name,
                              association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                              account_id: @account.id,
                              source: '102',
                              accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                              })
        end
        get :index, controller_params(version: 'private', filter: :accessible)
        assert_response 200
        match_json(private_api_ticket_templates_index_pattern)
      end
    end
  end
end

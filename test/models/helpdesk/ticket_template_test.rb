require_relative '../../test_helper'
['account_helper.rb', 'ticket_template_helper.rb', 'group_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"

class TicketTemplateModelTest < ActiveSupport::TestCase
  include TicketTemplateHelper
  include AccountHelper
  include AgentHelper
  include GroupHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    before_all
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def before_all
    @account = Account.current
    @agent = get_admin
    @groups = []
    @current_user = User.current
    @account.ticket_templates.destroy_all
    3.times { @groups << create_group(@account) }
  end

  def test_build_child_assn_attributes_with_multiple_child_ids
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
      child_template.save
      @template.build_child_assn_attributes(child_template.id)
      @template.save
      assert_equal @template.children[0].id, @account.ticket_templates.find(@template.children[0].child_template_id).parents[0].id
    end
  end

  def test_build_child_assn_attributes_with_multiple_child_ids_with_error
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
      child_template.save
      Helpdesk::TicketTemplate.any_instance.stubs(:save!).raises(StandardError)
      @template.build_child_assn_attributes(child_template.id)
      Helpdesk::TicketTemplate.any_instance.unstub(:save!)
      assert_equal @template.children.empty?, true
    end
  end

  def test_retrieve_duplication_with_parent_id_with_duplicate
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
      child_template.save
      @template.build_child_assn_attributes(child_template.id)
      @template.save
      templ_ids = @template.retrieve_duplication({ parent_id: @template.id, name: child_template.name }, false)
      assert_equal templ_ids.empty?, false
    end
  end
end

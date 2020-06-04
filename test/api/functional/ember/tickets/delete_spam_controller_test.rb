require_relative '../../../test_helper'
module Ember
  module Tickets
    class DeleteSpamControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper

      BULK_CREATE_TICKET_COUNT = 2

      def wrap_cname(params)
        { delete_spam: params }
      end

      def ticket_params_hash
        cc_emails = [Faker::Internet.email, Faker::Internet.email]
        subject = Faker::Lorem.words(10).join(' ')
        description = Faker::Lorem.paragraph
        email = Faker::Internet.email
        tags = [Faker::Name.name, Faker::Name.name]
        @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
        params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                        priority: 2, status: 2, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                        due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
        params_hash
      end

      def test_empty_trash
        delete :empty_trash, construct_params({ version: 'private' }, {})
        assert_response 204
      end

      def test_empty_spam
        delete :empty_spam, construct_params({ version: 'private' }, {})
        assert_response 204
      end

      def test_delete_forever_with_no_params
        put :delete_forever, construct_params({ version: 'private' }, {})
        assert_response 400
        match_json([bad_request_error_pattern('ids', :missing_field)])
      end

      def test_delete_forever_with_invalid_tickets
        ticket_ids = create_n_tickets(2)
        invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20]
        put :delete_forever, construct_params({ version: 'private' }, {ids: [*ticket_ids, *invalid_ids]})
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { :id => :unable_to_perform } }
        invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern([], failures))
      end

      def test_delete_forever_success
        deleted_ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash.merge(deleted: true))
        spam_ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash.merge(spam: true))
        ticket_ids = deleted_ticket_ids + spam_ticket_ids
        put :delete_forever, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_delete_with_invalid_ticket_id
        delete :destroy, construct_params({ version: 'private' }, false).merge(id: 0)
        assert_response 404
      end

      def test_delete_with_unauthorized_ticket_id
        ticket = create_ticket
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
        delete :destroy, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      def test_delete_with_valid_ticket_id
        ticket = create_ticket
        assert !ticket.deleted?
        delete :destroy, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 204
        assert ticket.reload.deleted?
      end

      def test_restore_with_invalid_ticket_id
        put :restore, construct_params({ version: 'private' }, false).merge(id: 0)
        assert_response 404
      end

      def test_restore_with_unauthorized_ticket_id
        ticket = create_ticket(deleted: true)
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
        put :restore, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      def test_restore_with_valid_ticket_id
        tags = Faker::Lorem.words(3).uniq
        ticket = create_ticket(tag_names: tags.join(','))
        delete :destroy, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert ticket.reload.deleted?
        put :restore, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 204
        assert !ticket.reload.deleted?
        assert ticket.tags.count == tags.size
      end

      def test_spam_with_invalid_ticket_id
        put :spam, construct_params({ version: 'private' }, false).merge(id: 0)
        assert_response 404
      end

      def test_spam_with_unauthorized_ticket_id
        ticket = create_ticket
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
        put :spam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      def test_spam_with_errors
        ticket = create_ticket(spam: true)
        put :spam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 404
      end

      def test_spam_with_valid_ticket_id
        ticket = create_ticket
        assert !ticket.spam?
        put :spam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 204
        assert ticket.reload.spam?
      end

      def test_unspam_with_invalid_ticket_id
        put :unspam, construct_params({ version: 'private' }, false).merge(id: 0)
        assert_response 404
      end

      def test_unspam_with_unauthorized_ticket_id
        ticket = create_ticket(spam: true)
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
        put :unspam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      end

      def test_unspam_with_errors
        ticket = create_ticket
        put :unspam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 404
      end

      def test_unspam_with_valid_ticket_id
        tags = Faker::Lorem.words(3).uniq
        ticket = create_ticket(tag_names: tags.join(','))
        put :spam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert ticket.reload.spam?
        put :unspam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 204
        assert !ticket.reload.spam?
        assert ticket.tags.count == tags.size
      end

      def test_bulk_delete_with_no_params
        put :bulk_delete, construct_params({ version: 'private' }, {})
        assert_response 400
        match_json([bad_request_error_pattern('ids', :missing_field)])
      end

      def test_bulk_delete_with_invalid_ids
        ticket_ids = create_n_tickets(2)
        invalid_ids = [ticket_ids.last + 20, ticket_ids.last + 30]
        ids_to_delete = [*ticket_ids, *invalid_ids]
        put :bulk_delete, construct_params({ version: 'private' }, {ids: ids_to_delete})
        failures = {}
        invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern(ticket_ids, failures))
        assert_response 202
      end

      def test_bulk_delete_with_valid_ids
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        put :bulk_delete, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_delete_tickets_without_access
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        User.any_instance.stubs(:can_view_all_tickets?).returns(false)
        put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
        User.any_instance.unstub(:can_view_all_tickets?)
        failures = {}
        ticket_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern([], failures))
        assert_response 202
      end

      def test_bulk_delete_tickets_with_group_access
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
        group = create_group_with_agents(@account, agent_list: [@agent.id])
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash.merge(group_id: group.id))
        put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      end

      def test_bulk_delete_tickets_with_assigned_access
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
        Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        put :bulk_delete, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
        Helpdesk::Ticket.any_instance.unstub(:responder_id)
      end

      def test_bulk_spam_with_no_params
        put :bulk_spam, construct_params({ version: 'private' }, {})
        assert_response 400
        match_json([bad_request_error_pattern('ids', :missing_field)])
      end

      def test_bulk_spam_with_invalid_ids
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        invalid_ids = [ticket_ids.last + 20, ticket_ids.last + 30]
        ids_list = [*ticket_ids, *invalid_ids]
        put :bulk_spam, construct_params({ version: 'private' }, {ids: ids_list})
        failures = {}
        invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern(ticket_ids, failures))
        assert_response 202
      end

      def test_bulk_spam_with_valid_ids
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        put :bulk_spam, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_spam_tickets_without_access
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        User.any_instance.stubs(:can_view_all_tickets?).returns(false)
        put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
        User.any_instance.unstub(:can_view_all_tickets?)
        failures = {}
        ticket_ids.each { |id| failures[id] = { :id => :"is invalid" } }
        match_json(partial_success_response_pattern([], failures))
        assert_response 202
      end

      def test_bulk_spam_tickets_with_group_access
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
        group = create_group_with_agents(@account, agent_list: [@agent.id])
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash.merge(group_id: group.id))
        put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
      end

      def test_bulk_spam_tickets_with_assigned_access
        User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
        User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
        User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
        Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        put :bulk_spam, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
        Helpdesk::Ticket.any_instance.unstub(:responder_id)
      end

      def test_bulk_restore_with_invalid_ids
        valid_ticket = create_ticket(ticket_params_hash.merge(deleted: true))
        ticket_ids = [valid_ticket.display_id + 10, valid_ticket.display_id + 20]
        put :bulk_restore, construct_params({ version: 'private' }, {ids: [*ticket_ids, valid_ticket.display_id]})
        failures = {}
        ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        assert_response 202
        match_json(partial_success_response_pattern([valid_ticket.display_id], failures))
      end

      def test_bulk_restore_valid
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash.merge(deleted: true))
        put :bulk_restore, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_unspam_with_invalid_ids
        valid_ticket = create_ticket(ticket_params_hash.merge(spam: true))
        ticket_ids = [valid_ticket.display_id + 10, valid_ticket.display_id + 20]
        put :bulk_unspam, construct_params({ version: 'private' }, {ids: [*ticket_ids, valid_ticket.display_id]})
        failures = {}
        ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern([valid_ticket.display_id], failures))
        assert_response 202
      end

      def test_bulk_unspam_valid
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash.merge(spam: true))
        put :bulk_unspam, construct_params({ version: 'private' }, {ids: ticket_ids})
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_spam_with_valid_ticket_id_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket = create_ticket({}, group)
        login_as(agent)
        put :spam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 403
      ensure
        group.destroy if group.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_unspam_with_valid_ticket_id_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket = create_ticket({ spam: true }, group)
        login_as(agent)
        put :unspam, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 403
      ensure
        group.destroy if group.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_restore_with_valid_ticket_id_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket = create_ticket(ticket_params_hash.merge(deleted: true), group)
        login_as(agent)
        put :restore, construct_params({ version: 'private' }, false).merge(id: ticket.display_id)
        assert_response 403
      ensure
        group.destroy if group.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_delete_invalid_ids_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket1 = create_ticket({}, group1)
        ticket2 = create_ticket({}, group2)
        ticket_ids = [ticket1.display_id, ticket2.display_id]
        login_as(agent)
        put :bulk_delete, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        failures = {}
        failure_ticket_ids = [ticket1.display_id]
        success_ticket_ids = [ticket2.display_id]
        failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(success_ticket_ids, failures))
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_spam_invalid_ids_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket1 = create_ticket({}, group1)
        ticket2 = create_ticket({}, group2)
        ticket_ids = [ticket1.display_id, ticket2.display_id]
        login_as(agent)
        put :bulk_spam, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        failures = {}
        failure_ticket_ids = [ticket1.display_id]
        success_ticket_ids = [ticket2.display_id]
        failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(success_ticket_ids, failures))
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_restore_invalid_ids_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket1 = create_ticket(ticket_params_hash.merge(deleted: true), group1)
        ticket2 = create_ticket(ticket_params_hash.merge(deleted: true), group2)
        ticket_ids = [ticket1.display_id, ticket2.display_id]
        login_as(agent)
        put :bulk_restore, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        failures = {}
        failure_ticket_ids = [ticket1.display_id]
        success_ticket_ids = [ticket2.display_id]
        failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(success_ticket_ids, failures))
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_unspam_invalid_ids_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket1 = create_ticket(ticket_params_hash.merge(spam: true), group1)
        ticket2 = create_ticket(ticket_params_hash.merge(spam: true), group2)
        ticket_ids = [ticket1.display_id, ticket2.display_id]
        login_as(agent)
        put :bulk_restore, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        failures = {}
        failure_ticket_ids = [ticket1.display_id]
        success_ticket_ids = [ticket2.display_id]
        failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(success_ticket_ids, failures))
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_delete_forever_invalid_ids_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket1 = create_ticket(ticket_params_hash.merge(spam: true), group1)
        ticket2 = create_ticket(ticket_params_hash.merge(spam: true), group2)
        ticket_ids = [ticket1.display_id, ticket2.display_id]
        login_as(agent)
        put :delete_forever, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 202
        failures = {}
        failure_ticket_ids = [ticket1.display_id]
        success_ticket_ids = [ticket2.display_id]
        failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(success_ticket_ids, failures))
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end
    end
  end
end

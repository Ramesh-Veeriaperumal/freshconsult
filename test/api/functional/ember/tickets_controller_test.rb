require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb', 'shared_ownership_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module Ember
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include ScenarioAutomationsTestHelper
    include AttachmentsTestHelper
    include GroupHelper
    include CannedResponsesHelper
    include CannedResponsesTestHelper
    include SocialTestHelper
    include SocialTicketsCreationHelper
    include SurveysTestHelper
    include PrivilegesHelper
    include AccountTestHelper
    include SharedOwnershipTestHelper

    CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze

    def setup
      super
      @private_api = true
      Sidekiq::Worker.clear_all
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.current.features.es_v2_writes.destroy
      Account.current.reload
      
      before_all
    end

    @@before_all_run = false

    def before_all
      @account.sections.map(&:destroy)
      return if @@before_all_run
      @account.features.freshfone.create
      @account.features.forums.create
      @account.ticket_fields.custom_fields.each(&:destroy)
      Helpdesk::TicketStatus.find(2).update_column(:stop_sla_timer, false)
      @@ticket_fields = []
      @@custom_field_names = []
      @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
      @@choices_custom_field_names = @@ticket_fields.map(&:name)
      CUSTOM_FIELDS.each do |custom_field|
        next if %w(dropdown country state city).include?(custom_field)
        @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
        @@custom_field_names << @@ticket_fields.last.name
      end
      @@before_all_run = true
    end

    def wrap_cname(params)
      { ticket: params }
    end

    def get_user_with_multiple_companies
      user_company = @account.user_companies.group(:user_id).having(
        'count(user_id) > 1 '
      ).last
      if user_company.present?
        user_company.user
      else
        new_user = add_new_user(@account)
        new_user.user_companies.create(company_id: get_company.id, default: true)
        other_company = create_company
        new_user.user_companies.create(company_id: other_company.id)
        new_user.reload
      end
    end

    def get_user_with_default_company
      user_company = @account.user_companies.group(:user_id).having('count(*) = 1 ').last
      if user_company.present?
        user_company.user
      else
        new_user = add_new_user(@account)
        new_user.user_companies.create(company_id: get_company.id, default: true)
        new_user.reload
      end
    end

    def get_company
      company = Company.first
      return company if company
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      company
    end

    def ticket_params_hash
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = Faker::Lorem.words(3).uniq
      @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: 2, status: 2, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id }
      params_hash
    end

    def update_ticket_params_hash
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      @update_group ||= create_group_with_agents(@account, agent_list: [agent.id])
      params_hash = { description: description, subject: subject, priority: 4, status: 7, type: 'Incident',
                      responder_id: agent.id, tags: %w(update_tag1 update_tag2),
                      due_by: 12.days.since.iso8601, fr_due_by: 4.days.since.iso8601, group_id: @update_group.id }
      params_hash
    end

    def test_index_with_invalid_filter_id
      get :index, controller_params(version: 'private', filter: @account.ticket_filters.last.id + 10)
      assert_response 400
      match_json([bad_request_error_pattern(:filter, :absent_in_db, resource: :ticket_filter, attribute: :filter)])
    end

    def test_index_with_all_tickets_filter
      # Private API should filter all tickets with last 30 days created_at limit
      test_ticket = create_ticket(created_at: 2.months.ago)
      get :index, controller_params(version: 'private', filter: 'all_tickets', include: 'count')
      assert_response 200
      assert response.api_meta[:count] != @account.tickets.where(spam: false, deleted: false).count
    end

    def test_index_with_invalid_filter_names
      get :index, controller_params(version: 'private', filter: Faker::Lorem.word)
      assert_response 400
      valid_filters = %w(
        spam deleted overdue pending open due_today new
        monitored_by new_and_my_open all_tickets unresolved
        article_feedback my_article_feedback
        watching on_hold
        raised_by_me shared_by_me shared_with_me
      )
      match_json([bad_request_error_pattern(:filter, :not_included, list: valid_filters.join(', '))])
    end

    def test_index_with_invalid_only_param
      get :index, controller_params(version: 'private', only: Faker::Lorem.word)
      assert_response 400
      match_json([bad_request_error_pattern(:only, :not_included, list: 'count')])
    end

    def test_index_with_invalid_query_hash
      get :index, controller_params(version: 'private', query_hash: Faker::Lorem.word)
      assert_response 400
      match_json([bad_request_error_pattern(:query_hash, :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: String, prepend_msg: :input_received)])
    end

    def test_index_with_no_params
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket }
      get :index, controller_params(version: 'private')
      assert_response 200
      refute response.api_meta.present?
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_filter_id
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(priority: 4) }
      ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
      get :index, controller_params(version: 'private', filter: ticket_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_filter_name
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(requester_id: @agent.id) }
      get :index, controller_params(version: 'private', filter: 'raised_by_me')
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_query_hash
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(priority: 2, requester_id: @agent.id) }
      query_hash_params = {
        '0' => { 'condition' => 'priority', 'operator' => 'is', 'value' => 2, 'type' => 'default' },
        '1' => { 'condition' => 'requester_id', 'operator' => 'is_in', 'value' => [@agent.id], 'type' => 'default' }
      }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_ids
      ticket_ids = []
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| ticket_ids << create_ticket(priority: 2, requester_id: @agent.id).display_id }
      get :index, controller_params({ version: 'private', ids: ticket_ids.join(',') }, false)
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_dates
      get :index, controller_params({ version: 'private', updated_since: Time.zone.now.iso8601 }, false)
      assert_response 200
      response = parse_response @response.body
      time_now = Time.zone.now.iso8601
      assert_equal 0, response.size
      tkt = create_ticket
      tkt.update_attributes(priority: 3)
      get :index, controller_params({ version: 'private', updated_since: time_now }, false)

      Rails.logger.debug '-' * 100
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    end

    def test_index_with_survey_result
      ticket = create_ticket
      result = []
      3.times do
        result << create_survey_result(ticket, 3)
      end
      get :index, controller_params(version: 'private', include: 'survey')
      assert_response 200
      match_json(private_api_ticket_index_pattern(true))
    end

    def test_index_without_survey_enabled
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = create_ticket
      default_survey = Account.current.features?(:default_survey)
      custom_survey = Account.current.features?(:custom_survey)

      # Check why sidekiq is running inline here

      Account.current.features.default_survey.destroy if default_survey
      Account.current.features.custom_survey.destroy if custom_survey
      Account.current.reload
      get :index, controller_params(version: 'private', include: 'survey')
      assert_response 400
      match_json([bad_request_error_pattern('include', :require_feature, feature: 'Custom survey')])
      Account.current.features.default_survey.create if default_survey
      Account.current.features.custom_survey.create if custom_survey
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_index_with_full_requester_info
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket }
      get :index, controller_params(version: 'private', include: 'requester')
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, true))
    end

    def test_index_with_restricted_requester_info
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket }
      remove_privilege(User.current, :view_contacts)
      get :index, controller_params(version: 'private', include: 'requester')
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, true))
      add_privilege(User.current, :view_contacts)
    end

    def test_index_with_agent_as_requester
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(requester_id: add_test_agent(@account, role: Role.find_by_name('Agent').id).id) }
      get :index, controller_params(version: 'private', include: 'requester')
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, true))
    end

    def test_index_with_company_side_load
      get :index, controller_params(version: 'private', include: 'company')
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, false, true))
    end

    def test_index_with_only_count
      get :index, controller_params(version: 'private', only: 'count')
      assert_response 200
      assert response.api_meta[:count] == @account.tickets.where(['spam = false AND deleted = false AND created_at > ?', 30.days.ago]).count
      match_json([])
    end

    def test_show_with_survey_result
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = create_ticket
      result = []
      3.times do
        result << create_survey_result(ticket, 3)
      end
      get :show, controller_params(version: 'private', id: ticket.display_id, include: 'survey')
      assert_response 200
      match_json(ticket_show_pattern(ticket, result.last))
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_show_without_survey_enabled
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = create_ticket
      result = []
      3.times do
        result << create_survey_result(ticket, 3)
      end
      default_survey = Account.current.features?(:default_survey)
      custom_survey = Account.current.features?(:custom_survey)
      Account.current.features.default_survey.destroy if default_survey
      Account.current.features.custom_survey.destroy if custom_survey
      Account.current.reload
      get :show, controller_params(version: 'private', id: ticket.display_id, include: 'survey')
      assert_response 400
      match_json([bad_request_error_pattern('include', :require_feature, feature: 'Custom survey')])
      Account.current.features.default_survey.create if default_survey
      Account.current.features.custom_survey.create if custom_survey
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_ticket_show_with_fone_call
      # while creating freshfone account during tests MixpanelWrapper was throwing error, so stubing that
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = new_ticket_from_call
      remove_wrap_params
      assert ticket.reload.freshfone_call.present?
      get :show, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_ticket_show_with_ticket_topic
      ticket = new_ticket_from_forum_topic
      remove_wrap_params
      get :show, construct_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
    end

    def test_create_with_incorrect_attachment_type
      attachment_ids = %w(A B C)
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids)
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_with_invalid_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = ticket_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
      assert_response 400
    end

    def test_create_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = ticket_params_hash.merge(attachment_ids: [attachment_id])
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
      post :create, construct_params({ version: 'private' }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_create_with_errors
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids)
      Helpdesk::Ticket.any_instance.stubs(:save).returns(false)
      post :create, construct_params({ version: 'private' }, params_hash)
      Helpdesk::Ticket.any_instance.unstub(:save)
      assert_response 500
    end

    def test_create_with_attachment_ids
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.size == attachment_ids.size
    end

    def test_create_without_source
      params_hash = ticket_params_hash.clone
      params_hash.delete(:source)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      latest_ticket = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(latest_ticket))
      assert latest_ticket.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone]
    end

    def test_create_with_attachment_and_attachment_ids
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = ticket_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private' }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.size == (attachments.size + 1)
    end

    def test_create_with_invalid_cloud_files
      cloud_file_params = [{ filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 10_000 }]
      params = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      match_json([bad_request_error_pattern(:application_id, :invalid_list, list: '10000')])
    end

    def test_create_with_cloud_files
      cloud_file_params = [{ filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 },
                           { filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }]
      params_hash = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.cloud_files.count == 2
    end

    def test_create_with_shared_attachments
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params_hash = ticket_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.count == 1
    end

    def test_create_with_all_attachments
      # normal attachment
      file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
      # cloud file
      cloud_file_params = [{ filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }]
      # shared attachment
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      # draft attachment
      draft_attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)

      attachment_ids = canned_response.shared_attachments.map(&:attachment_id) | [draft_attachment.id]
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids, attachments: [file], cloud_files: cloud_file_params)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private' }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.count == 3
      assert Helpdesk::Ticket.last.cloud_files.count == 1
    end

    def test_create_without_company_id
      sample_requester = get_user_with_default_company
      params = {
        requester_id: sample_requester.id,
        status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
      }
      post :create, construct_params({ version: 'private' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.owner_id, sample_requester.company_id
      assert_response 201
    end

    def test_create_with_company_id
      Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
      company = get_company
      sample_requester = add_new_user(@account)
      sample_requester.company_id = company.id
      sample_requester.save!
      params = {
        requester_id: sample_requester.id,
        company_id: company.id, status: 2,
        priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
      }
      post :create, construct_params({ version: 'private' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.owner_id, company.id
      assert_response 201
    ensure
      Account.any_instance.unstub(:multiple_user_companies_enabled?)
    end

    def test_create_with_other_company_id_of_requester
      Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
      sample_requester = get_user_with_multiple_companies
      company_id = (sample_requester.company_ids - [sample_requester.company_id]).sample
      params = {
        requester_id: sample_requester.id,
        company_id: company_id, status: 2,
        priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
      }
      post :create, construct_params({ version: 'private' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.owner_id, company_id
      assert_response 201
    ensure
      Account.any_instance.unstub(:multiple_user_companies_enabled?)
    end

    def test_execute_scenario_without_params
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, {})
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :missing_field)])
    end

    def test_execute_scenario_with_invalid_ticket_id
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id + 20
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      assert_response 404
    end

    def test_execute_scenario_without_ticket_access
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
    end

    def test_execute_scenario_without_scenario_access
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      ScenarioAutomation.any_instance.stubs(:check_user_privilege).returns(false)
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      ScenarioAutomation.any_instance.unstub(:check_user_privilege)
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :inaccessible_value, resource: :scenario, attribute: :scenario_id)])
    end

    def test_execute_scenario
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      assert_response 204
    end

    # tests for latest note
    # 1. invalid ticket id
    # 2. ticket with no permission
    # 2. with valid ticket id
    #   a. with no notes
    #   b. with a private note
    #   c. with a public note
    #   d. with a reply

    def test_latest_note_ticket_with_invalid_id
      get :latest_note, construct_params({ version: 'private', id: 0 }, false)
      assert_response 404
    end

    def test_latest_note_ticket_without_permissison
      ticket = create_ticket
      user_stub_ticket_permission
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 403
      user_unstub_ticket_permission
    end

    def test_latest_note_ticket_without_notes
      ticket = create_ticket
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 204
    end

    def test_latest_note_ticket_with_private_note
      ticket = create_ticket
      note = create_note(custom_note_params(ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:note], true))
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    end

    def test_latest_note_ticket_with_public_note
      ticket = create_ticket
      note = create_note(custom_note_params(ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:note]))
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    end

    def test_latest_note_ticket_with_reply
      ticket = create_ticket
      reply = create_note(custom_note_params(ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:email]))
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(reply))
    end

    # tests for split note
    # 1. invalid ticket id
    # 2. invalid note id
    # 3. ticket with no permission
    # 4. Successfull split with
    #     a. normal reply
    #     b. twitter reply
    #     c. fb reply
    # 5. error in saving ticket
    # 6. verify attachmnets moving

    def test_split_note_invalid_ticket_id
      put :split_note, construct_params({ version: 'private', id: 0, note_id: 2 }, false)
      assert_response 404
    end

    def test_split_note_invalid_note_id
      ticket = create_ticket
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: 2 }, false)
      assert_response 404
    end

    def test_split_note_ticket_without_permission
      ticket = create_ticket
      user_stub_ticket_permission
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: 2 }, false)
      assert_response 403
      user_unstub_ticket_permission
    end

    def test_split_note_with_normal_reply
      ticket = create_ticket
      note = create_normal_reply_for(ticket)
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
    end

    def test_split_note_with_twitter_reply
      ticket, note = twitter_ticket_and_note
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
    end

    def test_split_note_with_fb_reply
      ticket, note = create_fb_ticket_and_note
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
    end

    def test_split_note_error_in_saving
      ticket = create_ticket
      note = create_normal_reply_for(ticket)
      @controller.stubs(:ticket_attributes).returns({})
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: note.id }, false)
      @controller.unstub(:ticket_attributes)
      assert_response 400
    end

    def test_split_note_with_attachments
      ticket = create_ticket
      note = create_normal_reply_for(ticket)
      add_attachments_to_note(note, rand(2..5))

      attachment_ids = note.attachments.map(&:id)
      assert note.cloud_files.present?
      assert note.attachments.present?

      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
      verify_attachments_moving(attachment_ids)
    end

    def test_update_properties_with_no_params
      ticket = create_ticket
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, {})
      assert_response 400
      match_json([bad_request_error_pattern('request', :fill_a_mandatory_field, field_names: 'due_by, agent, group, status')])
    end

    def test_update_properties
      ticket = create_ticket
      dt = 10.days.from_now.utc.iso8601
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      update_group = create_group_with_agents(@account, agent_list: [agent.id])
      tags = Faker::Lorem.words(3).uniq
      params_hash = { due_by: dt, responder_id: agent.id, status: 2, priority: 4, group_id: update_group.id, tags: tags }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(ticket.reload))
      assert_equal dt, ticket.due_by.to_time.iso8601
      assert_equal agent.id, ticket.responder_id
      assert_equal 2, ticket.status
      assert_equal 4, ticket.priority
      assert_equal tags.count, ticket.tags.count
      assert_equal update_group.id, ticket.group_id
    end

    def test_update_properties_validation_for_closure_status
      ticket = create_ticket
      params_hash = { status: 4 }
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      ticket_field.update_attribute(:required_for_closure, false)
      assert_response 400
      match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: String)])
    end

    def test_update_properties_closure_of_parent_ticket_failure
      parent_ticket = create_ticket
      child_ticket = create_ticket
      Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      params_hash = { status: 4 }
      put :update_properties, construct_params({ version: 'private', id: parent_ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('status', :unresolved_child)])
    end

    def test_update_properties_closure_of_parent_ticket_success
      parent_ticket = create_ticket
      child_ticket = create_ticket(status: 4)
      Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      params_hash = { status: 4 }
      put :update_properties, construct_params({ version: 'private', id: parent_ticket.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(parent_ticket.reload))
      assert_equal 4, parent_ticket.status
    end

    def test_update_properties_closure_status_without_notification
      ticket = create_ticket
      params_hash = { status: 5, skip_close_notification: true }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(ticket.reload))
      assert_equal 5, ticket.status
    end

    def test_show_with_facebook_post
      Account.stubs(:current).returns(Account.first)
      ticket = create_ticket_from_fb_post
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
      Account.unstub(:current)
    end

    def test_show_with_tweet
      Account.stubs(:current).returns(Account.first)
      ticket = create_twitter_ticket
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
      Account.unstub(:current)
    end

    def test_show_with_facebook_feature_disabled
      Account.stubs(:current).returns(Account.first)
      ticket = create_ticket_from_fb_post
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      fb_enabled = Account.current.features?(:facebook)
      Account.current.features.facebook.destroy if fb_enabled
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
      Account.current.features.facebook.create if fb_enabled
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Account.unstub(:current)
    end

    def test_show_with_twitter_feature_disabled
      Account.stubs(:current).returns(Account.first)
      ticket = create_twitter_ticket
      twitter_enabled = Account.current.features?(:twitter)
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.current.features.twitter.destroy if twitter_enabled
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
      Account.current.features.twitter.create if twitter_enabled
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Account.unstub(:current)
    end

    def test_show_with_full_requester_info
      t = create_ticket
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(ticket, nil, true))
    end

    def test_show_with_restricted_requester_info
      t = create_ticket
      remove_privilege(User.current, :view_contacts)
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(ticket, nil, true))
      add_privilege(User.current, :view_contacts)
    end

    def test_show_with_agent_as_requester
      t = create_ticket(requester_id: add_test_agent(@account, role: Role.find_by_name('Agent').id).id)
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(ticket, nil, true))
    end

    def test_show_with_valid_meta
      t = create_ticket(requester_id: add_test_agent(@account, role: Role.find_by_name('Agent').id).id)

      # Adding meta note
      meta_data = "created_by: 1\ntime: 2017-03-14 15:13:13 +0530\nuser_agent: Mozilla/5.0"
      meta_note = t.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])

      if meta_note
        meta_note.note_body_attributes = { body: meta_data }
      else
        meta_note = t.notes.build(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
                                  note_body_attributes: {
                                    body: meta_data
                                  },
                                  private: true,
                                  notable: t,
                                  user_id: User.current.id)
      end
      meta_note.save

      get :show, controller_params(version: 'private', id: t.display_id)
      assert_response 200
      json = ActiveSupport::JSON.decode(response.body)
      assert_equal %w(created_by time user_agent).sort, json['meta'].keys.sort
    end

    def test_show_with_invalid_meta
      t = create_ticket(requester_id: add_test_agent(@account, role: Role.find_by_name('Agent').id).id)
      # Adding meta note
      meta_data = "user_agent: Mozilla/5.0 (Windows NT 6.1; Trident/7.0; swrinfo: 2576:cbc.ad.colchester.gov.uk:kayd; rv:11.0) like Gecko\nreferrer: https://colchesterboroughcouncil.freshservice.com/itil/custom_reports/ticket/2271"
      meta_note = t.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])

      if meta_note
        meta_note.note_body_attributes = { body: meta_data }
      else
        meta_note = t.notes.build(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
                                  note_body_attributes: {
                                    body: meta_data
                                  },
                                  private: true,
                                  notable: t,
                                  user_id: User.current.id)
      end
      meta_note.save

      get :show, controller_params(version: 'private', id: t.display_id)
      assert_response 200

      json = ActiveSupport::JSON.decode(response.body)
      assert_equal ({}), json['meta']
    end

    def test_update_ticket_source
      params_hash = update_ticket_params_hash.merge(source: 3)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:source, :invalid_field)])
    end

    def test_update_closure_status_without_notification
      t = ticket
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      update_params = { custom_fields: { 'test_custom_text' => 'Hello' }, status: 5, skip_close_notification: true }
      params_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(update_params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
      assert_equal 5, t.status
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_closure_of_parent_ticket_failure
      parent_ticket = create_ticket
      child_ticket = create_ticket
      Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      params_hash = { status: 4 }
      put :update, construct_params({ version: 'private', id: parent_ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('status', :unresolved_child)])
    end

    def test_update_closure_of_parent_ticket_success
      parent_ticket = create_ticket
      child_ticket = create_ticket(status: 4)
      Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      params_hash = { status: 4 }
      put :update, construct_params({ version: 'private', id: parent_ticket.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(parent_ticket.reload))
      assert_equal 4, parent_ticket.status
    end

    def test_update_with_attachment_ids
      t = ticket
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = update_ticket_params_hash.merge(attachment_ids: attachment_ids)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
      assert ticket.attachments.size == attachment_ids.size
    end

    def test_update_with_cloud_files
      t = ticket
      cloud_file_params = [{ filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 },
                           { filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }]
      params_hash = update_ticket_params_hash.merge(cloud_files: cloud_file_params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
      assert ticket.cloud_files.count == 2
    end

    def test_update_with_shared_attachments
      t = create_ticket
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params_hash = update_ticket_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert ticket.attachments.count == 1
    end

    def test_update_with_company_id
      Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
      t = ticket
      sample_requester = get_user_with_multiple_companies
      t.update_attributes(requester: sample_requester)
      company_id = sample_requester.user_companies.where(default: false).first.company.id
      params = { company_id: company_id }
      put :update, construct_params({ version: 'private', id: t.display_id }, params)
      t.reload
      assert t.owner_id == company_id
      match_json(ticket_show_pattern(t))
      assert_response 200
    ensure
      Account.any_instance.unstub(:multiple_user_companies_enabled?)
    end

    # Test when group restricted agent trying to access the ticket which has been assigned to its group
    def test_ticket_access_by_assigned_group_agent
      group = @account.groups.first
      ticket = create_ticket({:status => 2}, group)
      group_restricted_agent = add_agent_to_group(group_id = group.id,
                                                  ticket_permission = 2, role_id = @account.roles.agent.first.id)
      login_as(group_restricted_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)

      assert_match /#{ticket.description_html}/, response.body
    end


    # Test access of ticket by ticket restricted agent who can view only those tickets which has been assigned to him
    def test_ticket_access_by_assigned_agent
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      ticket = create_ticket({:status => 2, :responder_id => ticket_restricted_agent.id})
      login_as(ticket_restricted_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)

      assert_match /#{ticket.description_html}/, response.body
    end

    # Test when Internal agent have group tickets access.
    def test_ticket_access_for_group_restricted_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        group_restricted_agent = add_agent_to_group(group_id = @internal_group.id,
                                                    ticket_permission = 2, role_id = @account.roles.first.id)
        ticket = create_ticket({:status => @status.status_id}, nil, @internal_group)
        login_as(group_restricted_agent)
        get :show, controller_params(version: 'private', id: ticket.display_id)
        assert_match /#{ticket.description_html}/, response.body
      end
    end

    # Test ticket access by Internal agent when ticket has been assigned to him
    def test_ticket_access_by_Internal_restricted_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id}, nil, @internal_group)
        login_as(@internal_agent)
        get :show, controller_params(version: 'private', id: ticket.display_id)

        assert_match /#{ticket.description_html}/, response.body
      end
    end

    def test_ticket_assignment_to_internal_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => 2, :responder_id => @responding_agent.id}, group = @account.groups.find_by_id(2))
        # params = {
        #   :status => @status.status_id,
        #   :internal_group_id => @internal_group.id,
        #   :internal_agent_id => @internal_agent.id
        # }
        params = {
          :status => @status.status_id,
          :internal_group_id => @internal_group.id,
          :internal_agent_id => @internal_agent.id
        }
        put :update, construct_params({ version: 'private', id: ticket.display_id }, params)

        login_as(@internal_agent)
        ticket.reload
        # get :show, controller_params(version: 'private', id: ticket.display_id)
        assert_match /#{ticket.description_html}/, response.body
      end
    end

    def test_tracker_create
      enable_adv_ticketing(:link_tickets) do
        Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
        create_ticket
        agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        ticket = Helpdesk::Ticket.last
        params_hash = ticket_params_hash.merge(email: agent.email, related_ticket_ids: [ticket.display_id])
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 201
        latest_ticket = Helpdesk::Ticket.last
        ticket.reload
        match_json(ticket_show_pattern(latest_ticket))
        assert ticket.related_ticket?
      end
    end

    def test_tracker_create_with_contact_email
      enable_adv_ticketing(:link_tickets) do
        create_ticket
        ticket = Helpdesk::Ticket.last
        params_hash = ticket_params_hash.merge(related_ticket_ids: [ticket.display_id])
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('email', nil, append_msg: I18n.t('ticket.tracker_agent_error'))])
        assert !ticket.related_ticket?
      end
    end

    def test_child_create
      enable_adv_ticketing(:parent_child_tickets) do
        Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
        create_parent_ticket
        parent_ticket = Helpdesk::Ticket.last
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 201
        latest_ticket = Helpdesk::Ticket.last
        match_json(ticket_show_pattern(latest_ticket))
      end
    end

    def test_create_child_to_parent_with_max_children
      enable_adv_ticketing(:parent_child_tickets) do
        Helpdesk::Ticket.any_instance.stubs(:associates).returns((10..21).to_a)
        parent_ticket = create_parent_ticket
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', nil, append_msg: I18n.t('ticket.parent_child.count_exceeded', count: TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT))])
      end
    end

    def test_create_child_to_a_invalid_parent
      enable_adv_ticketing(:parent_child_tickets) do
        Helpdesk::Ticket.any_instance.stubs(:associates).returns((10..21).to_a)
        parent_ticket = create_parent_ticket
        parent_ticket.update_attributes(spam: true)
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', nil, append_msg: I18n.t('ticket.parent_child.permission_denied'))])
      end
    end
  end
end

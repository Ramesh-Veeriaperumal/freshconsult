require_relative '../../test_helper'
require 'webmock/minitest'
['canned_responses_helper.rb', 'social_tickets_creation_helper.rb', 'ticket_template_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb', 'groups_test_helper.rb', 'shared_ownership_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['advanced_scope_test_helper.rb', 'tickets_test_helper.rb', 'bot_response_test_helper.rb', 'ticket_properties_suggester_test_helper'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module Ember
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include ScenarioAutomationsTestHelper
    include AttachmentsTestHelper
    include GroupsTestHelper
    include CannedResponsesHelper
    include CannedResponsesTestHelper
    include SocialTestHelper
    include SocialTicketsCreationHelper
    include SurveysTestHelper
    include PrivilegesHelper
    include ContactFieldsHelper
    include AccountTestHelper
    include SharedOwnershipTestHelper
    include UsersTestHelper
    include TicketTemplateHelper
    include AwsTestHelper
    include TicketActivitiesTestHelper
    include TicketTemplateHelper
    include CustomFieldsTestHelper
    include ArchiveTicketTestHelper
    include DiscussionsTestHelper
    include BotResponseTestHelper
    include TicketFiltersHelper
    include TicketPropertiesSuggesterTestHelper
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant
    include FieldServiceManagementTestHelper
    include AdvancedScopeTestHelper
    ARCHIVE_DAYS = 120
    TICKET_UPDATED_DATE = 150.days.ago

    BULK_ATTACHMENT_CREATE_COUNT = 2

    def setup
      super
      @private_api = true
      Sidekiq::Worker.clear_all
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.current.features.es_v2_writes.destroy
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      Account.current.reload
      @account.sections.map(&:destroy)
      destroy_all_fsm_fields_and_service_task_type
      tickets_controller_before_all(@@before_all_run)
      @account.add_feature :scenario_automation
      @@before_all_run=true unless @@before_all_run
    end

    def teardown
      super
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end

    @@before_all_run=false

    def wrap_cname(params)
      query_params = params[:query_params]
      cparams = params.clone
      cparams.delete(:query_params)
      return query_params.merge(ticket: cparams) if query_params

      { ticket: cparams }
    end

    def construct_sections(field_name)
      if field_name == 'type'
        return SECTIONS_FOR_TYPE
      else
        return SECTIONS_FOR_CUSTOM_DROPDOWN
      end
    end

    def clear_field_options
      @account.ticket_fields.custom_fields.each do |x|
        x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
      end
    end

    def destroy_all_fsm_fields_and_service_task_type
      fsm_fields = fsm_custom_field_to_reserve.collect { |x| x[:name] + "_#{Account.current.id}" }
      fsm_fields.each do |fsm_field|
        Account.current.ticket_fields.find_by_name(fsm_field).try(:destroy)
      end
      Account.current.picklist_values.find_by_value(SERVICE_TASK_TYPE).try(:destroy)
      Role.find_by_name(FIELD_SERVICE_MANAGER_ROLE_NAME).try(:destroy)
    end

   def change_subscription_state(subscription_state)
      subscription = Account.current.subscription
      subscription.state = subscription_state
      subscription.save
    end

    def fetch_email_config
      @account.email_configs.where('active = true').first || create_email_config
    end

    def ticket
      ticket = Helpdesk::Ticket.where('source != ?', 10).last || create_ticket(ticket_params_hash)
      ticket
    end

    def account
      @account ||= Account.current
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
      cc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
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

    def setup_fsm
      Account.stubs(:current).returns(Account.first)
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      perform_fsm_operations
      Account.reset_current_account
      Account.stubs(:current).returns(Account.first)
    end

    def destroy_fsm
      cleanup_fsm
      Account.unstub(:field_service_management_enabled?)
      Account.unstub(:current)
    end

    def test_index_with_invalid_filter_id
      get :index, controller_params(version: 'private', filter: @account.ticket_filters.last.id + 10)
      assert_response 400
      match_json([bad_request_error_pattern(:filter, :absent_in_db, resource: :ticket_filter, attribute: :filter)])
    end

    def test_index_with_all_tickets_filter
      # Private API should filter all tickets with last 30 days created_at limit
      test_ticket = create_ticket(created_at: 2.months.ago)
      Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      assert_response 200
      response_body = JSON.parse(response.body)
      fetched_ticket = response_body.first
      assert_equal fetched_ticket['nr_due_by'], nil
      assert_equal fetched_ticket['nr_escalated'], false
    ensure
      Account.any_instance.unstub(:next_response_sla_enabled?)
    end

    def test_index_with_fb_ticket
      ticket = create_ticket_from_fb_post
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      assert_response 200
      response_body = JSON.parse(response.body)
      fetched_ticket = response_body.first
      assert_equal fetched_ticket['social_additional_info']['fb_msg_type'], ticket.fb_post.msg_type
    ensure
      ticket.destroy
    end

    def test_index_with_twitter_ticket
      ticket = create_twitter_ticket
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      assert_response 200
      response_body = JSON.parse(response.body)
      fetched_ticket = response_body.first
      assert_equal fetched_ticket['social_additional_info']['tweet_type'], ticket.tweet.tweet_type.to_s
    ensure
      ticket.destroy
    end

    def test_index_with_custom_file_field
      custom_field = create_custom_field_dn('test_signature_file', 'file')
      ticket = create_ticket
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      assert_response 200
      response = parse_response @response.body
      file_field = response.select { |h| h['custom_fields'].key?('test_signature_file') }.present?
      assert_equal file_field, true
    ensure
      ticket.destroy
      custom_field.destroy
    end

    def test_index_with_invalid_filter_names
      Account.current.stubs(:freshconnect_enabled?).returns(true)
      get :index, controller_params(version: 'private', filter: Faker::Lorem.word)
      assert_response 400
      valid_filters = %w(
        spam deleted overdue pending open due_today new
        monitored_by new_and_my_open all_tickets unresolved
        article_feedback unresolved_article_feedback my_article_feedback
        watching on_hold
        raised_by_me shared_by_me shared_with_me
        unresolved_service_tasks unassigned_service_tasks overdue_service_tasks service_tasks_due_today service_tasks_starting_today
      )
      match_json([bad_request_error_pattern(:filter, :not_included, list: valid_filters.join(', '))])
      Account.current.unstub(:freshconnect_enabled?)
    end

    def test_index_with_invalid_only_param
      get :index, controller_params(version: 'private', only: Faker::Lorem.word)
      assert_response 400
      match_json([bad_request_error_pattern(:only, :not_included, list: 'count')])
    end

    def test_index_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      get :index, controller_params(version: 'private', only: Faker::Lorem.word)
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_index_with_invalid_query_hash
      get :index, controller_params(version: 'private', query_hash: Faker::Lorem.word)
      assert_response 400
      match_json([bad_request_error_pattern(:query_hash, :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: String, prepend_msg: :input_received)])
    end

    # def test_index_with_no_params
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    #   get :index, controller_params(version: 'private')
    #   assert_response 200
    #   refute response.api_meta.present?
    #   match_json(private_api_ticket_index_pattern)
    # end

    # def test_index_with_filter_id
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], priority: 4)
    #   ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
    #   get :index, controller_params(version: 'private', filter: ticket_filter.id)
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern)
    # end

    # def test_index_with_filter_name
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], requester_id: @agent.id)
    #   get :index, controller_params(version: 'private', filter: 'raised_by_me')
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern)
    # end

    # def test_index_with_filter_name_ongoing_collab
    #   collab_tickets_ids = create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], requester_id: @agent.id)
    #   Account.current.stubs(:collab_settings).returns(Collab::Setting.new)
    #   Collaboration::Ticket.any_instance.stubs(:fetch_tickets).returns(collab_tickets_ids)
    #   Collaboration::Ticket.any_instance.stubs(:fetch_count).returns(collab_tickets_ids.size())

    #   feature_flag = Account.current.has_feature?(:collaboration)
    #   Account.current.set_feature(:collaboration) unless !feature_flag

    #   get :index, controller_params(version: 'private', filter: 'ongoing_collab')
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern)
    # ensure
    #   Account.current.reset_feature(:collaboration) unless !feature_flag
    #   Account.current.unstub(:collab_settings)
    #   Collaboration::Ticket.any_instance.unstub(:fetch_tickets)
    #   Collaboration::Ticket.any_instance.unstub(:fetch_count)
    # end

    # def test_index_with_query_hash
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], priority: 2, requester_id: @agent.id)
    #   query_hash_params = {
    #     '0' => { 'condition' => 'priority', 'operator' => 'is', 'value' => 4, 'type' => 'default' },
    #     '1' => { 'condition' => 'requester_id', 'operator' => 'is_in', 'value' => [@agent.id], 'type' => 'default' }
    #   }
    #   get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern)
    # end

    # def test_index_with_ids
    #   ticket_ids = create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], priority: 2, requester_id: @agent.id)
    #   get :index, controller_params({ version: 'private', ids: ticket_ids.join(',') }, false)
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern)
    # end

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
      match_json(private_api_ticket_index_pattern(true, false, false, 'created_at', 'desc', true))
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

    # def test_index_with_full_requester_info
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    #   get :index, controller_params(version: 'private', include: 'requester')
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern(false, true))
    # end

    # def test_index_with_restricted_requester_info
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    #   remove_privilege(User.current, :view_contacts)
    #   get :index, controller_params(version: 'private', include: 'requester')
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern(false, true))
    #   add_privilege(User.current, :view_contacts)
    # end

    # def test_index_with_agent_as_requester
    #   create_n_tickets(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], requester_id: @agent.id)
    #   get :index, controller_params(version: 'private', include: 'requester')
    #   assert_response 200
    #   match_json(private_api_ticket_index_pattern(false, true))
    # end

    def test_index_with_description_in_include
      tickets = []
      3.times do
        tickets << create_ticket
      end
      get :index, controller_params(include: 'description')
      assert_response 200
      response = parse_response @response.body
      tkts = Helpdesk::Ticket.where(deleted: 0, spam: 0)
                             .created_in(Helpdesk::Ticket.created_in_last_month)
                             .order('created_at DESC')
                             .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
      assert_equal tkts.count, response.size
      param_object = OpenStruct.new(stats: true)
      pattern = tkts.map do |tkt|
        index_ticket_pattern_with_associations(tkt, param_object, [:description, :description_text])
      end
      match_json(pattern)
    ensure
      tickets.map(&:destroy)
    end

    def test_index_with_requester_nil
      ticket = create_ticket
      ticket.requester.destroy
      get :index, controller_params(version: 'private', include: 'requester')
      assert_response 200
      requester_hash = JSON.parse(response.body).select { |x| x['id'] == ticket.display_id }.first['requester']
      ticket.destroy
      assert requester_hash.nil?
    end

    def test_index_with_company_side_load
      get :index, controller_params(version: 'private', include: 'company')
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, false, true, 'created_at', 'desc', true))
    end

    def test_index_with_only_count
      @account.stubs(:count_es_enabled?).returns(false)
      get :index, controller_params(version: 'private', only: 'count')
      assert_response 200
      assert response.api_meta[:count] == @account.tickets.where(['spam = false AND deleted = false AND created_at > ?', 30.days.ago]).count
      match_json([])
    ensure
      @account.unstub(:count_es_enabled?)
    end

    def test_meta_count_with_internal_agent_or_agent_filter
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        query_hash_params = { '0' => query_hash_param('any_agent_id', 'is_in', [@agent.id.to_s, '-1']), '1' => query_hash_param('created_at', 'is_greater_than', 'last_month') }
        @account.stubs(:count_es_enabled?).returns(false)
        get :index, controller_params({ version: 'private', only: 'count', query_hash: query_hash_params }, false)
        assert_response 200
        assert_equal response.api_meta[:count], @account.tickets.where(['((responder_id = ? OR ISNULL(responder_id)) OR (internal_agent_id = ? OR ISNULL(internal_agent_id))) AND spam = false AND deleted = false AND created_at > ?', @agent.id, @internal_agent.id, 30.days.ago]).count
      end
    end

    def query_hash_param(condition, operator, value, type = 'default')
      {
        'condition' => condition,
        'operator' => operator,
        'value' => value,
        'type' => type
      }
    end

    def test_meta_data_with_next_page
      tickets = []
      31.times do
        tickets << create_ticket
      end
      get :index, controller_params(version: 'private')
      assert_response 200
      assert response.api_meta[:next_page] == true
    ensure
      tickets.each(&:destroy)
    end

    def test_meta_data_without_next_page
      ticket = create_ticket
      ticket_count = Account.current.tickets.count
      last_page = (ticket_count.to_f / 30).ceil
      get :index, controller_params(version: 'private', page: last_page)
      assert_response 200
      assert response.api_meta[:next_page] == false
    ensure
      ticket.destroy
    end

    def test_index_with_exclude_custom_fields
      get :index, controller_params(version: 'private', exclude: 'custom_fields')
      assert_response 200
      match_json(private_api_ticket_index_pattern(true, false, false, 'created_at', 'desc', true, ['custom_fields']))
    end

    def test_index_with_exclude_with_incorrect_field
      get :index, controller_params(version: 'private', exclude: 'attachment')
      assert_response 400
      match_json([bad_request_error_pattern('exclude', :not_included, list: ApiTicketConstants::EXCLUDABLE_FIELDS.join(','))])
    end

    def test_index_with_article_feedback_filter
      article_meta = create_article
      article = article_meta.solution_articles[0]
      create_article_feedback_ticket(article.id)

      get :index, controller_params(version: 'private', filter: 'article_feedback', portal_id: @account.main_portal.id, language_id: article.language_id)
      assert_response 200
    end

    def test_unresolved_article_feedback_filter
      article1_meta = create_article
      article1 = article1_meta.solution_articles[0]
      create_article_feedback_ticket(article1.id)

      article2 = create_article.solution_articles[0]
      create_article_feedback_ticket(article2.id)

      get :index, controller_params(version: 'private', filter: 'unresolved_article_feedback', article_id: article1_meta.id, language_id: article1.language_id)
      assert_response 200
      assert_equal 1, (parse_response @response.body).size
    end

    def test_index_with_ids_of_ticket_created_greater_than_month
      ticket = Account.current.tickets.last
      ticket.created_at = Time.now - 45.days
      ticket.save
      get :index, controller_params(version: 'private', ids: ticket.display_id)
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    end

    def test_show_when_account_suspended
      ticket = create_ticket
      change_subscription_state('suspended')
      get :show, controller_params(version: 'private', id: ticket.display_id)
      change_subscription_state('trial')
      assert_response 200
    end

    def test_put_when_account_suspended
      ticket = create_ticket
      change_subscription_state('suspended')
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, {})
      change_subscription_state('trial')
      assert_response 402
    end

    def test_post_when_account_suspended
      change_subscription_state('suspended')
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids)
      post :create, construct_params({ version: 'private' }, params_hash)
      change_subscription_state('trial')
      assert_response 402
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
      match_json(ticket_show_pattern(ticket.reload, result.last))
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

    def test_ticket_show_with_ticket_topic
      ticket = new_ticket_from_forum_topic
      remove_wrap_params
      get :show, construct_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket.reload))
    end

    def test_ticket_show_with_archive_child
      ticket = create_ticket
      archive_ticket = create_archive_and_child(ticket)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      Account.current.features.archive_tickets.destroy
      pattern = ticket_show_pattern(ticket)
      pattern[:archive_ticket] = { :subject => archive_ticket.subject, :id => archive_ticket.display_id }
      assert_response 200
      match_json(pattern)
    end

    def test_show_with_custom_file_field
      custom_field = create_custom_field_dn('test_signature_file', 'file')
      ticket = create_ticket
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      response = parse_response @response.body
      file_field = response['custom_fields'].key? 'test_signature_file'
      assert_equal file_field, true
    ensure
      ticket.destroy
      custom_field.destroy
    end

    def test_create_with_incorrect_attachment_type
      attachment_ids = %w(A B C)
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids)
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_with_requester_having_two_emails
      sample_requester = add_user_with_multiple_emails(@account, 2)
      sample_requester_email = sample_requester.emails[1]
      params_hash = ticket_params_hash.merge!(email: sample_requester_email, requester_id: sample_requester.id)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      response_body = JSON.parse(response.body)
      assert_equal response_body['sender_email'], sample_requester_email
      assert_equal response_body['requester_id'], sample_requester.id
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

    def test_create_with_invalid_freshcaller_id
      fc_call_id = Faker::Number.number(3).to_i
      params_hash = ticket_params_hash.merge(fc_call_id: fc_call_id)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('fc_call_id', 'Value not present: ' + fc_call_id.to_s, code: 'invalid_value')])
    end

    def test_create_with_valid_freshcaller_id
      fc_call_id = Faker::Number.number(3).to_i
      params_hash = ticket_params_hash.merge(fc_call_id: fc_call_id)
      Account.current.freshcaller_calls.new(fc_call_id: fc_call_id).save
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
    ensure
      Account.current.freshcaller_calls.find_by_fc_call_id(fc_call_id).destroy
      Account.current.tickets.last.destroy
    end

    def test_create_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = ticket_params_hash.merge(attachment_ids: [attachment_id])
      invalid_attachment_size = @account.attachment_limit + 10
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_size.megabytes)
      post :create, construct_params({ version: 'private' }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_size} MB")])
      assert_response 400
    end

    def test_create_ticket_with_file_field
      attachment = create_file_ticket_field_attachment
      custom_field = create_custom_field_dn('test_file_field', 'file')
      Account.first.make_current
      params_hash = ticket_params_hash.merge(custom_fields: { test_file_field: attachment.id })
      Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      response_body = JSON.parse(response.body)
      assert_equal response_body['nr_due_by'], nil
      assert_equal response_body['nr_escalated'], false
      assert_equal attachment.id, response_body['custom_fields']['test_file_field']
      attachment = Account.current.attachments.find(attachment.id)
      assert_equal attachment.attachable_type, 'Helpdesk::FileTicketField'
      assert_equal attachment.description, custom_field.column_name
    ensure
      Account.any_instance.unstub(:next_response_sla_enabled?)
      custom_field.destroy
      Account.reset_current_account
    end

    def test_create_ticket_with_nil_file_field_value
      custom_field = create_custom_field_dn('test_file_field', 'file')
      Account.first.make_current
      params_hash = ticket_params_hash.merge(custom_fields: { test_file_field: nil })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      response_body = JSON.parse(response.body)
      assert_equal nil, response_body['custom_fields']['test_file_field']
    ensure
      custom_field.destroy
      Account.reset_current_account
    end

    def test_create_ticket_with_invalid_file_attachment_type
      attachment_id = create_attachment(attachable_type: 'Tickets Image Upload', attachable_id: @agent.id).id
      custom_field = create_custom_field_dn('test_invalid_file_field', 'file')
      Account.first.make_current
      params_hash = ticket_params_hash.merge(custom_fields: { test_invalid_file_field: attachment_id })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('custom_fields.test_invalid_file_field', :invalid_attachment, code: :invalid_attachment)])
    ensure
      custom_field.destroy
      Account.reset_current_account
    end

    def test_create_ticket_with_nil_file_field_attachment_when_required_for_submission
      custom_field = create_custom_field_dn('test_file_field', 'file', true, false)
      Account.first.make_current
      params_hash = ticket_params_hash.merge(custom_fields: { test_file_field: nil })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('custom_fields.test_file_field', :blank, code: :blank)])
    ensure
      custom_field.destroy
      Account.reset_current_account
    end

    def test_update_ticket_with_random_data_in_file_field
      custom_field = create_custom_field_dn('test_file_field', 'file')
      Account.first.make_current
      ticket = create_ticket
      assert_not_nil ticket
      ticket.update_attribute(:custom_field, custom_field.name.to_sym => 'Name')
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
    ensure
      custom_field.destroy
      ticket.destroy
      Account.reset_current_account
    end

    def test_close_ticket_with_nil_file_field_attachment_when_required_for_submission
      custom_field = create_custom_field_dn('test_file_field', 'file', true, false)
      Account.first.make_current
      ticket = create_ticket
      assert_not_nil ticket
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern('custom_fields.test_file_field', :blank, code: :blank)])
    ensure
      custom_field.destroy
      Account.reset_current_account
    end

    def test_close_ticket_with_file_field_attachment_value_when_required_for_submission
      attachment = create_file_ticket_field_attachment
      custom_field = create_custom_field_dn('test_file_field', 'file', true, false)
      Account.first.make_current
      ticket = create_ticket(custom_field: { custom_field.name => attachment.id })
      assert_not_nil ticket
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
      response_body = JSON.parse(response.body)
      assert_equal Helpdesk::Ticketfields::TicketStatus::CLOSED, response_body['status']
    ensure
      custom_field.destroy
      Account.reset_current_account
    end

    def test_create_ticket_with_invalid_file_field_attachment_size
      attachment = create_file_ticket_field_attachment(content_file_size: 2.megabytes)
      custom_field = create_custom_field_dn('test_file_field', 'file')
      Account.first.make_current
      Account.any_instance.stubs(:attachment_limit).returns(1)
      params_hash = ticket_params_hash.merge(custom_fields: { test_file_field: attachment.id })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:ticket, :exceeded_total_file_field_attachments_size, code: :exceeded_total_file_field_attachments_size)])
    ensure
      custom_field.destroy
      Account.any_instance.unstub(:attachment_limit)
      Account.reset_current_account
    end

    def test_create_ticket_with_non_uniq_field_attachments
      flexifield_def = FlexifieldDef.find_by_account_id_and_module(@account.id, 'Ticket')
      file_field1_col_name = flexifield_def.first_available_column('file')
      attachment = create_file_ticket_field_attachment
      custom_field1 = create_custom_field_dn('test_file_field1', 'file', false, false, flexifield_name: file_field1_col_name)
      Account.first.make_current
      file_field2_col_name = flexifield_def.first_available_column('file')
      custom_field2 = create_custom_field_dn('test_file_field2', 'file', false, false, flexifield_name: file_field2_col_name)
      Account.first.make_current
      params_hash = ticket_params_hash.merge(custom_fields: { test_file_field1: attachment.id, test_file_field2: attachment.id })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:ticket, :non_unique_file_field_attachment_ids, code: :non_unique_file_field_attachment_ids)])
    ensure
      custom_field1.destroy
      custom_field2.destroy
      Account.reset_current_account
    end

    def test_create_ticket_with_invalid_image_for_file_field
      attachment = create_file_ticket_field_attachment
      custom_field = create_custom_field_dn('test_file_field', 'file')
      Account.first.make_current
      Helpdesk::Attachment.any_instance.stubs(:image?).returns(false)
      params_hash = ticket_params_hash.merge(custom_fields: { test_file_field: attachment.id })
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('custom_fields.test_file_field', :invalid_image, code: :invalid_image)])
    ensure
      custom_field.destroy
      Helpdesk::Attachment.any_instance.unstub(:image?)
      Account.reset_current_account
    end

    def test_close_ticket_with_file_field_value_when_required_for_closure
      attachment = create_file_ticket_field_attachment
      custom_field = create_custom_field_dn('test_file_field', 'file', false, true)
      Account.first.make_current
      ticket = create_ticket(custom_field: { custom_field.name => attachment.id })
      assert_not_nil ticket
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
      response_body = JSON.parse(response.body)
      assert_equal Helpdesk::Ticketfields::TicketStatus::CLOSED, response_body['status']
    ensure
      custom_field.destroy
      Account.any_instance.unstub(:attachment_limit)
      Account.reset_current_account
    end

    def test_close_ticket_with_nil_file_field_value_when_required_for_closure
      custom_field = create_custom_field_dn('test_file_field', 'file', false, true)
      Account.first.make_current
      ticket = create_ticket
      assert_not_nil ticket
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern('custom_fields.test_file_field', :blank, code: :blank)])
    ensure
      custom_field.destroy
      Account.any_instance.unstub(:attachment_limit)
      Account.reset_current_account
    end

    def test_update_without_support_bot
      @account.add_feature(:support_bot)
      t = create_ticket
      t.source = 12
      t.save!
      @account.reload
      @account.revoke_feature(:support_bot)
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: t.display_id, version: 'private' }, update_params)
      assert_response 200
    end

    def test_update_ticket_file_field_with_draft_attachment
      flexifield_def = FlexifieldDef.find_by_account_id_and_module(@account.id, 'Ticket')
      file_field1_col_name = flexifield_def.first_available_column('file')
      custom_field1 = create_custom_field_dn('test_file_field1', 'file', false, false, flexifield_name: file_field1_col_name)
      Account.first.make_current
      file_field2_col_name = flexifield_def.first_available_column('file')
      custom_field2 = create_custom_field_dn('test_file_field2', 'file', false, false, flexifield_name: file_field2_col_name)
      Account.first.make_current
      attachment1 = create_file_ticket_field_attachment
      attachment2 = create_file_ticket_field_attachment
      attachment3 = create_file_ticket_field_attachment
      ticket = create_ticket(custom_field: { custom_field1.name => attachment1.id, custom_field2.name => attachment2.id })
      assert_not_nil ticket
      update_params = { custom_fields: { test_file_field1: attachment3.id } }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
      Account.current.reload
      assert_equal true, Account.current.attachments.where(id: attachment1.id).blank?
      assert_equal false, Account.current.attachments.where(id: attachment2.id).blank?
      assert_equal false, Account.current.attachments.where(id: attachment3.id).blank?
      response_body = JSON.parse(response.body)
      assert_equal attachment3.id, response_body['custom_fields']['test_file_field1']
      assert_equal attachment2.id, response_body['custom_fields']['test_file_field2']
    ensure
      custom_field2.destroy
      custom_field1.destroy
      ticket.reload.destroy
      Account.reset_current_account
    end

    def test_update_ticket_file_field_with_nil_value
      flexifield_def = FlexifieldDef.find_by_account_id_and_module(@account.id, 'Ticket')
      file_field1_col_name = flexifield_def.first_available_column('file')
      custom_field1 = create_custom_field_dn('test_file_field1', 'file', false, false, flexifield_name: file_field1_col_name)
      Account.first.make_current
      file_field2_col_name = flexifield_def.first_available_column('file')
      custom_field2 = create_custom_field_dn('test_file_field2', 'file', false, false, flexifield_name: file_field2_col_name)
      Account.first.make_current
      attachment1 = create_file_ticket_field_attachment
      attachment2 = create_file_ticket_field_attachment
      ticket = create_ticket(custom_field: { custom_field1.name => attachment1.id, custom_field2.name => attachment2.id })
      assert_not_nil ticket
      update_params = { custom_fields: { test_file_field1: nil } }
      Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
      Account.current.reload
      assert_equal true, Account.current.attachments.where(id: attachment1.id).blank?
      assert_equal false, Account.current.attachments.where(id: attachment2.id).blank?
      response_body = JSON.parse(response.body)
      assert_equal response_body['nr_due_by'], nil
      assert_equal response_body['nr_escalated'], false
      assert_nil response_body['custom_fields']['test_file_field1']
      assert_equal attachment2.id, response_body['custom_fields']['test_file_field2']
    ensure
      Account.any_instance.unstub(:next_response_sla_enabled?)
      custom_field2.destroy
      custom_field1.destroy
      ticket.reload.destroy
      Account.reset_current_account
    end

    def test_create_with_invalid_email_and_custom_field_email
      create_custom_field('email', 'text')
      params = { email: Faker::Name.name, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, custom_fields: { email: 0 } }
      post :create, construct_params({ version: 'private' }, params)
      match_json([
        bad_request_error_pattern(:email, :invalid_format, accepted: 'valid email address'),
        bad_request_error_pattern(custom_field_error_label('email'), :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)
      ])
      assert_response 400
    end

    def test_create_with_invalid_email_new_regex
      Account.stubs(:current).returns(Account.first || create_test_account)
      Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
      create_custom_field('email', 'text')
      params = { email: 'test.@test.com', status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, custom_fields: { email: 0 } }
      post :create, construct_params({ version: 'private' }, params)
      match_json([bad_request_error_pattern(:email, :invalid_format, accepted: 'valid email address'),
                  bad_request_error_pattern(custom_field_error_label('email'), :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)])
      assert_response 400
    ensure
      Account.any_instance.unstub(:new_email_regex_enabled?)
      Account.unstub(:current)
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
      assert latest_ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:phone]
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
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 10_000 }]
      params = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      match_json([bad_request_error_pattern(:application_id, :invalid_list, list: '10000')])
    end

    def test_create_cloud_files_with_no_app_id
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL }]
      params = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
    end

    def test_create_cloud_files_with_no_file_name
      cloud_file_params = [{ url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      params = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
    end

    def test_create_cloud_files_with_no_file_url
      cloud_file_params = [{ name: 'image.jpg', application_id: 20 }]
      params = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
    end

    def test_create_with_cloud_files
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      params_hash = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.cloud_files.count == 1
    end

    def test_create_with_shared_attachments_using_canned_response
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params_hash = ticket_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      stub_attachment_to_io do
        post :create, construct_params({ version: 'private' }, params_hash)
      end
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert canned_response.shared_attachments.count == 1
      assert_not_equal canned_response.shared_attachments.first.id, Helpdesk::Ticket.last.attachments.first.id
      assert Helpdesk::Ticket.last.attachments.count == 1
    end

    def test_create_with_shared_attachments_using_ticket_templates
      @account = Account.first.make_current
      @agent = get_admin
      @groups = []
      @groups << create_group(@account)
      @current_user = User.current
      # normal ticket template attachment
      ticket_template = create_tkt_template(
        name: Faker::Name.name,
        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
        account_id: @account.id,
        accessible_attributes: {
          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        },
        attachments: [{ resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }]
      )
      assert ticket_template.attachments.first.attachable_type == 'Helpdesk::TicketTemplate'
      params_hash = ticket_params_hash.merge(attachment_ids: ticket_template.attachments.map(&:id))
      stub_attachment_to_io do
        post :create, construct_params({ version: 'private' }, params_hash)
      end
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert ticket_template.attachments.count == 1
      assert ticket_template.attachments.first.attachable_type == 'Helpdesk::TicketTemplate'
      assert_not_equal ticket_template.attachments.first.id, Helpdesk::Ticket.last.attachments.first.id
      assert Helpdesk::Ticket.last.attachments.count == 1
    end

    def test_create_with_all_attachments
      # normal attachment
      file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
      # cloud file
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      # shared attachment
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      # draft attachment
      draft_attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)

      attachment_ids = canned_response.shared_attachments.map(&:attachment_id) | [draft_attachment.id]
      params_hash = ticket_params_hash.merge(attachment_ids: attachment_ids, attachments: [file], cloud_files: cloud_file_params)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      stub_attachment_to_io do
        post :create, construct_params({ version: 'private' }, params_hash)
      end
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.count == 3
      assert Helpdesk::Ticket.last.cloud_files.count == 1
    end

    def test_create_with_inline_attachment_ids
      inline_attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      params_hash = ticket_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      ticket = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(ticket))
      assert_equal inline_attachment_ids.size, ticket.inline_attachments.size
    end

    def test_create_with_invalid_inline_attachment_ids
      inline_attachment_ids, valid_ids, invalid_ids = [], [], []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
      end
      invalid_ids << 0
      BULK_ATTACHMENT_CREATE_COUNT.times do
        valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      inline_attachment_ids = invalid_ids + valid_ids
      params_hash = ticket_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
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

    def test_create_service_task_ticket
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          parent_ticket = create_ticket
          params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                     custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }
          post :create, construct_params({ version: 'private' }, params)
          assert_response 201
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_service_task_ticket_with_all_custom_fields
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          parent_ticket = create_ticket
          params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                     custom_fields: { cf_fsm_contact_name: 'test', cf_fsm_service_location: 'test', cf_fsm_phone_number: 'test', cf_fsm_appointment_start_time: '2019-10-10T12:23:00', cf_fsm_appointment_end_time: '2019-10-11T12:23:00' } }
          post :create, construct_params({ version: 'private' }, params)
          assert_response 201
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_service_task_ticket_with_all_custom_fields_invalid_appointment_time_range
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          parent_ticket = create_ticket
          params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                     custom_fields: { cf_fsm_contact_name: 'test', cf_fsm_service_location: 'test', cf_fsm_phone_number: 'test', cf_fsm_appointment_start_time: '2019-10-12T12:23:00', cf_fsm_appointment_end_time: '2019-10-11T12:23:00' } }
          post :create, construct_params({ version: 'private' }, params)
          assert_response 400
          match_json([bad_request_error_pattern('custom_fields.cf_fsm_appointment_end_time', :invalid_date_time_range)])
        ensure
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_create_service_task_ticket_with_invalid_values_for_datetime_fields
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          parent_ticket = create_ticket
          params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                     custom_fields: { cf_fsm_contact_name: 'test', cf_fsm_service_location: 'test', cf_fsm_phone_number: 'test', cf_fsm_appointment_start_time: 'test', cf_fsm_appointment_end_time: 'test' } }
          post :create, construct_params({ version: 'private' }, params)
          assert_response 400
          match_json([bad_request_error_pattern('custom_fields.cf_fsm_appointment_start_time', :invalid_date, accepted: 'combined date and time ISO8601'),
          bad_request_error_pattern('custom_fields.cf_fsm_appointment_end_time', :invalid_date, accepted: 'combined date and time ISO8601')])
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_service_task_ticket_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          params = { email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                   custom_fields: { cf_fsm_contact_name:
                    "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }
          post :create, construct_params({version: 'private'}, params)
          match_json([bad_request_error_pattern('ticket_type', :should_be_child, :type => SERVICE_TASK_TYPE, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_service_task_ticket_with_support_agent
      enable_adv_ticketing([:field_service_management]) do
       begin
         perform_fsm_operations
         Account.first.make_current
         parent_ticket = create_ticket
         params = { responder_id: @agent.id, parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                   custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }
         post :create, construct_params({version: 'private'}, params)
         assert_response 201
       ensure
        cleanup_fsm
       end
      end
    end

    def test_create_non_service_task_ticket_with_invalid_field_agent_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          field_agent = create_field_agent
          params = { responder_id: field_agent.id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2 }
          post :create, construct_params({version: 'private'}, params)
          match_json([bad_request_error_pattern('responder_id', :field_agent_not_allowed, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end


    def test_create_non_service_task_ticket_with_invalid_field_agent_and_group_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          field_group = create_field_agent_group
          field_agent = create_field_agent
          field_group.agent_groups.create(user_id: field_agent.id, group_id: field_agent.id)
          params = { group_id: field_group.id, responder_id: field_agent.id,  email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2 }
          post :create, construct_params({version: 'private'}, params)
          match_json([bad_request_error_pattern('group_id', :field_group_not_allowed, :code => :invalid_value),
                      bad_request_error_pattern('responder_id', :field_agent_not_allowed, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_create_service_task_ticket_with_invalid_field_group_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          group = create_group(@account)
          parent_ticket = create_ticket
          params = { group_id: group.id, parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2, type: SERVICE_TASK_TYPE,
                     custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }
          post :create, construct_params({version: 'private'}, params)
          match_json([bad_request_error_pattern('group_id', :only_field_group_allowed, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_non_service_task_ticket_with_invalid_field_group_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          field_group = create_field_agent_group
          params = { group_id: field_group.id, email: Faker::Internet.email,
                     description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                     priority: 2, status: 2 }
          post :create, construct_params({version: 'private'}, params)
          match_json([bad_request_error_pattern('group_id', :field_group_not_allowed, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_update_service_task_ticket_type_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          fsm_ticket = create_service_task_ticket
          params = {:type => "Question"}
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          match_json([bad_request_error_pattern('ticket_type', :from_service_task_not_possible, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
        end
      end
    end

    def test_update_service_task_ticket_type_with_all_fsm_fields_valid
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          fsm_ticket = create_service_task_ticket
          params = {custom_fields: { cf_fsm_contact_name: Faker::Lorem.characters(10), cf_fsm_service_location: Faker::Lorem.characters(10), cf_fsm_phone_number: Faker::Lorem.characters(10), cf_fsm_appointment_start_time: '2019-10-10T12:23:00', cf_fsm_appointment_end_time: '2019-10-11T12:23:00' }}
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
        ensure
          cleanup_fsm
        end
      end
    end

    def test_update_service_task_ticket_type_with_all_fsm_fields_invalid
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          fsm_ticket = create_service_task_ticket
          params = {custom_fields: { cf_fsm_contact_name: Faker::Lorem.characters(10), cf_fsm_service_location: Faker::Lorem.characters(10), cf_fsm_phone_number: Faker::Lorem.characters(10), cf_fsm_appointment_start_time: Faker::Lorem.characters(10), cf_fsm_appointment_end_time: Faker::Lorem.characters(10) }}
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 400
          match_json([bad_request_error_pattern('custom_fields.cf_fsm_appointment_start_time', :invalid_date, accepted: 'combined date and time ISO8601'),
          bad_request_error_pattern('custom_fields.cf_fsm_appointment_end_time', :invalid_date, accepted: 'combined date and time ISO8601')])
        ensure
          cleanup_fsm
        end
      end
    end

    def test_update_service_task_ticket_type_with_invalid_appointment_time_range
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          fsm_ticket = create_service_task_ticket
          params = {custom_fields: { cf_fsm_contact_name: 'test', cf_fsm_service_location: 'test', cf_fsm_phone_number: 'test', cf_fsm_appointment_start_time: '2019-10-12T10:23:00', cf_fsm_appointment_end_time: '2019-10-11T12:23:00'}}
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 400
          match_json([bad_request_error_pattern('custom_fields.cf_fsm_appointment_end_time', :invalid_date_time_range)])
        ensure
          cleanup_fsm
        end
      end
    end

    def test_update_non_service_task_ticket_to_service_task_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          ticket = create_ticket
          params = {:type => SERVICE_TASK_TYPE, custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }
          put :update, construct_params({ id: ticket.display_id, version: 'private' }, params)
          match_json([bad_request_error_pattern('ticket_type', :to_service_task_not_possible, :code => :invalid_value)])
          assert_response 400
        ensure
          cleanup_fsm
        end
      end
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

    def test_create_with_new_tag_without_privilege
      tags = Faker::Lorem.words(3).uniq
      tags = tags.map do |tag|
      #Timestamp added to make sure tag names are new
        tag = "#{tag}#{Time.now.to_i}"
        assert_equal @account.tags.map(&:name).include?(tag), false
        tag
      end
      User.current.reload
      remove_privilege(User.current, :create_tags)
      params = {
        requester_id: User.current.id,
        status: 2, priority: 2, tags: tags,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
      }
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      add_privilege(User.current, :create_tags)
    end

    def test_create_with_existing_tag_without_privilege
      tag = Faker::Lorem.word
      @account.tags.create(:name => tag) unless @account.tags.map(&:name).include?(tag)
      User.current.reload
      remove_privilege(User.current, :create_tags)
      params = {
        requester_id: User.current.id,
        status: 2, priority: 2, tags: [tag],
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
      }
      post :create, construct_params({ version: 'private' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.tags.count, 1
      assert_response 201
      add_privilege(User.current, :create_tags)
    end

    def test_create_with_tag_with_privilege
      tags = Faker::Lorem.words(3).uniq
      tags = tags.map do |tag|
      #Timestamp added to make sure tag names are new
        tag = "#{tag}#{Time.now.to_i}"
        assert_equal @account.tags.map(&:name).include?(tag), false
        tag
      end
      params = {
        requester_id: User.current.id,
        status: 2, priority: 2, tags: tags,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
      }
      post :create, construct_params({ version: 'private' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.tags.count, tags.count
      assert_response 201
    end

    def test_create_with_topic_id
      topic = @account.topics.first || create_test_topic(@account.forums.first, User.current)
      params_hash = ticket_params_hash.merge(topic_id: topic.id)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      ticket = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(ticket))
      assert_equal topic, ticket.topic
    end

    def test_create_with_invalid_topic_id
      params_hash = ticket_params_hash.merge(topic_id: 0)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('topic_id', :invalid_topic)])
    end

    def test_create_with_topic_with_ticket_already_created
      ticket = new_ticket_from_forum_topic
      params_hash = ticket_params_hash.merge(topic_id: ticket.topic.id)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('topic_id', :cannot_convert_topic_to_ticket, ticket_id: ticket.display_id)])
    end

    def test_create_with_topic_with_deleted_ticket
      deleted_ticket = new_ticket_from_forum_topic
      topic = deleted_ticket.topic
      deleted_ticket.update_attributes(deleted: true)
      params_hash = ticket_params_hash.merge(topic_id: topic.id)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      ticket = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(ticket))
      assert_equal topic, ticket.topic
    end

    def test_parse_template
      t = create_ticket
      params = {
        id: t.display_id,
        template_text: 'test # {{ticket.id}}',
        version: 'private'
      }
      post :parse_template, construct_params(params, false)
      assert_response 200
      str = "test # #{t.display_id}"
      match_json({ evaluated_text: str })
    end

    def test_ticket_field_suggestions_with_none_set
      WebMock.allow_net_connect!
      @account = Account.first.presence || create_test_account
      Account.stubs(:current).returns(@account)
      ticket = create_ticket_for_ticket_properties_suggester
      args = { ticket_id: ticket.id, action: 'predict', dispatcher_set_priority: false }
      response_stub = ResponseStub.new(ticket_properties_suggester_json, 200)
      HTTParty.stubs(:post).returns(response_stub)
      ::Freddy::TicketPropertiesSuggesterWorker.new.perform(args)
      ticket.reload
      get :ticket_field_suggestions, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      response = ticket_field_suggestions(ticket)

      assert_equal true, keys_present?(['priority', 'group', 'ticket_type'], response['ticket_field_suggestions'])
      WebMock.disable_net_connect!
    end

    def test_ticket_field_suggestions_with_priority_set
      WebMock.allow_net_connect!
      @account = Account.first.presence || create_test_account
      Account.stubs(:current).returns(@account)
      ticket = create_ticket_for_ticket_properties_suggester
      ticket.priority = 2
      ticket.save!
      args = { ticket_id: ticket.id, action: 'predict', dispatcher_set_priority: false }
      response_stub = ResponseStub.new(ticket_properties_suggester_json, 200)
      HTTParty.stubs(:post).returns(response_stub)
      ::Freddy::TicketPropertiesSuggesterWorker.new.perform(args)
      ticket.reload
      get :ticket_field_suggestions, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      response = ticket_field_suggestions(ticket)
      assert_equal true, keys_present?(['group', 'ticket_type'], response['ticket_field_suggestions'])
      WebMock.disable_net_connect!
    end

    def test_ticket_field_suggestions_with_group_set
      WebMock.allow_net_connect!
      @account = Account.first.presence || create_test_account
      Account.stubs(:current).returns(@account)
      ticket = create_ticket_for_ticket_properties_suggester
      group = @account.groups.new
      group.name = "test_group_for_ticket_properties_suggester"
      group.save!
      ticket.group = group
      ticket.save!
      args = { ticket_id: ticket.id, action: 'predict', dispatcher_set_priority: false }
      response_stub = ResponseStub.new(ticket_properties_suggester_json, 200)
      HTTParty.stubs(:post).returns(response_stub)
      ::Freddy::TicketPropertiesSuggesterWorker.new.perform(args)
      ticket.reload
      get :ticket_field_suggestions, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      response = ticket_field_suggestions(ticket)
      assert_equal true, keys_present?(['priority','ticket_type'], response['ticket_field_suggestions'])
      WebMock.disable_net_connect!
    end

    def test_ticket_field_suggestions_with_type_set
      WebMock.allow_net_connect!
      @account = Account.first.presence || create_test_account
      Account.stubs(:current).returns(@account)
      ticket = create_ticket_for_ticket_properties_suggester
      ticket_type = @account.ticket_fields.find_by_name('ticket_type')
      ticket.ticket_type  = ticket_type.picklist_values.first.value
      ticket.save!
      args = { ticket_id: ticket.id, action: 'predict', dispatcher_set_priority: false }
      response_stub = ResponseStub.new(ticket_properties_suggester_json, 200)
      HTTParty.stubs(:post).returns(response_stub)
      ::Freddy::TicketPropertiesSuggesterWorker.new.perform(args)
      ticket.reload
      get :ticket_field_suggestions, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      response = ticket_field_suggestions(ticket)
      assert_equal true, keys_present?(['priority', 'group'], response['ticket_field_suggestions'])
      WebMock.disable_net_connect!
    end

    def test_ticket_field_suggestions_with_all_set
      WebMock.allow_net_connect!
      @account = Account.first.presence || create_test_account
      Account.stubs(:current).returns(@account)
      ticket = create_ticket_for_ticket_properties_suggester
      ticket.priority = 2
      group = @account.groups.new
      group.name = "test_group_for_ticket_properties_suggester_all_set"
      group.save!
      ticket.group = group
      ticket_type = @account.ticket_fields.find_by_name('ticket_type')
      ticket.ticket_type  = ticket_type.picklist_values.first.value
      ticket.save!
      args = { ticket_id: ticket.id, action: 'predict', dispatcher_set_priority: false }
      response_stub = ResponseStub.new(ticket_properties_suggester_json, 200)
      HTTParty.stubs(:post).returns(response_stub)
      ::Freddy::TicketPropertiesSuggesterWorker.new.perform(args)
      ticket.reload
      get :ticket_field_suggestions, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      response = ticket_field_suggestions(ticket)
      assert_equal true, keys_absent?(['priority', 'group', 'ticket_type'], response['ticket_field_suggestions'])
      WebMock.disable_net_connect!
    end

    def test_parse_template_malformed
      t = create_ticket
      params = {
        id: t.display_id,
        template_text: 'test # {% if my_variable == blank %}',
        version: 'private'
      }
      post :parse_template, construct_params(params, false)
      assert_response 400
      match_json([bad_request_error_pattern('template_text', :"is invalid")])
    end

    def test_parse_template_without_param
      t = create_ticket
      params = {
        id: t.display_id,
        version: 'private'
      }
      post :parse_template, construct_params(params, false)
      assert_response 400
    end

    def test_parse_template_custom_field
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      t = create_ticket(custom_field: { ticket_field.name => 'Sample Text' })
      params = {
        id: t.display_id,
        template_text: 'test # {{ticket.id}} {{ticket.test_custom_text}}',
        version: 'private'
      }
      post :parse_template, construct_params(params, false)
      assert_response 200
      str = "test # #{t.display_id} Sample Text"
      match_json({ evaluated_text: str })
    end

    def test_parse_template_with_nested_placeholders
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      t = create_ticket({ responder_id: agent.id, requester_id: agent.id })
      params = {
        id: t.display_id,
        template_text: 'test # {{ticket.requester.email}} {{ticket.agent.email}}',
        version: 'private'
      }
      post :parse_template, construct_params(params, false)
      assert_response 200
      str = "test # #{t.requester.email} #{t.agent.email}"
      match_json({ evaluated_text: str })
    end

    def test_parse_template_without_placeholders
      t = create_ticket
      params = {
        id: t.display_id,
        template_text: 'test #',
        version: 'private'
      }
      post :parse_template, construct_params(params, false)
      assert_response 200
      match_json({ evaluated_text: 'test #' })
    end

    def test_execute_scenario_to_respond_403
      scn_auto = @account.scn_automations.first || create_scn_automation_rule(scenario_automation_params)
      ticket = @account.tickets.first || create_ticket(ticket_params_hash)
      @account.revoke_feature :scenario_automation
      @account.features.scenario_automations.destroy if @account.features.scenario_automations?
      put :execute_scenario, construct_params({ version: 'private', id: ticket.display_id }, scenario_id: scn_auto.id)
      assert_response 403
    end

    def test_create_with_section_fields_with_type_as_parent
      sections = construct_sections('type')
      type_field_id = @account.ticket_fields.find_by_field_type('default_ticket_type').id
      create_section_fields(type_field_id, sections)
      params = ticket_params_hash.merge(custom_fields: {}, type: 'Incident', description: '<b>test</b>')
      %w(paragraph dropdown).each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 201
    ensure
      clear_field_options
    end

    def test_create_with_section_fields_with_custom_dropdown_as_parent
      dd_field_id = create_custom_field_dropdown_with_sections.id
      sections = construct_sections('section_custom_dropdown')
      create_section_fields(dd_field_id, sections)
      params = ticket_params_hash.merge(custom_fields: { section_custom_dropdown: 'Choice 3' }, description: '<b>test</b>')
      ['paragraph'].each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 201
    ensure
      clear_field_options
    end

    def test_create_with_section_fields_with_parent_custom_dropdown_and_child_dependent
      dropdown_value = CUSTOM_FIELDS_CHOICES.sample
      sections = [
        {
          title: 'section1',
          value_mappingvalue_mapping: [dropdown_value],
          ticket_fields: ['dependent']
        }
      ]
      cust_dropdown_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      create_section_fields(cust_dropdown_field.id, sections, false)
      params = ticket_params_hash.merge(custom_fields: { test_custom_dropdown: dropdown_value }, description: '<b>test</b>')
      ['paragraph'].each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 201
    ensure
      clear_field_options
    end

    def test_create_from_email_with_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      Bot.any_instance.stubs(:email_channel).returns(true)
      @bot = @account.main_portal.bot || create_test_email_bot({email_channel: true})
      @account.reload
      ticket = create_ticket({source: 1})
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 1, ::Freddy::AgentSuggestArticles.jobs.size
      Bot.any_instance.unstub(:email_channel)
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
    end

    def test_create_ticket_ml_central_publish
      assert_nothing_raised do
        Account.any_instance.stubs(:email_bot_enabled?).returns(true)
        @account.reload
        ticket = create_ticket(source: 1)
        stub_request(:post, 'https://central-staging.freshworksapi.com/collector').to_return(body: '', status: 202)
        CentralPublisher::Worker.jobs.clear
        args = { 'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => { 'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i }}
        disptchr = Helpdesk::Dispatcher.new(args)
        disptchr.execute
      end
    ensure
      Account.any_instance.unstub(:email_bot_enabled?)
    end

    def test_create_ticket_ml_central_publish_with_error
      assert_nothing_raised do
        Account.any_instance.stubs(:email_bot_enabled?).returns(true)
        @account.reload
        ticket = create_ticket(source: 1)
        stub_request(:post, 'https://central-staging.freshworksapi.com/collector').to_raise(StandardError)
        CentralPublisher::Worker.jobs.clear
        args = { 'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => { 'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i } }
        disptchr = Helpdesk::Dispatcher.new(args)
        disptchr.execute
      end
    ensure
      Account.any_instance.unstub(:email_bot_enabled?)
    end

    def test_create_from_email_without_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(false)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      Account.any_instance.stubs(:agent_articles_suggest_enabled?).returns(false)
      ticket = create_ticket({source: 1})
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Freddy::AgentSuggestArticles.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
      Account.any_instance.unstub(:agent_articles_suggest_enabled?)
    end

    def test_create_from_email_without_email_bot_channel
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(false)
      Account.any_instance.stubs(:agent_articles_suggest_enabled?).returns(false)
      ticket = create_ticket({source: 1})
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Freddy::AgentSuggestArticles.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
      Account.any_instance.unstub(:agent_articles_suggest_enabled?)
    end

    def test_create_from_other_source_with_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      Account.any_instance.stubs(:agent_articles_suggest_enabled?).returns(false)
      ticket = create_ticket
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Freddy::AgentSuggestArticles.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
      Account.any_instance.unstub(:agent_articles_suggest_enabled?)
    end

    def test_spam_ticket_with_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      ticket = create_ticket({spam: true})
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Freddy::AgentSuggestArticles.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
    end

    def test_create_agent_suggest_articles
      Account.any_instance.stubs(:support_bot_configured?).returns(false)
      Account.any_instance.stubs(:agent_articles_suggest_enabled?).returns(true)
      @bot = @account.main_portal.bot || create_test_email_bot(email_channel: true)
      @account.reload
      ticket = create_ticket(source: 1)
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = { 'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => { 'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i } }
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 1, ::Freddy::AgentSuggestArticles.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:agent_articles_suggest_enabled?)
    end

    def test_create_without_agent_suggest_articles
      Account.any_instance.stubs(:support_bot_configured?).returns(false)
      Account.any_instance.stubs(:agent_articles_suggest_enabled?).returns(false)
      ticket = create_ticket(source: 1)
      ::Freddy::AgentSuggestArticles.jobs.clear
      args = { 'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => { 'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i } }
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Freddy::AgentSuggestArticles.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:agent_articles_suggest_enabled?)
    end

    def test_execute_scenario_without_params
      @account.add_feature(:scenario_automation)
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, {})
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :missing_field)])
    ensure
      @account.revoke_feature(:scenario_automation)
    end

    def test_execute_scenario_with_invalid_ticket_id
      @account.add_feature(:scenario_automation)
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id + 20
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      assert_response 404
    ensure
      @account.revoke_feature(:scenario_automation)
    end

    def test_execute_scenario_with_invalid_ticket_type
      @account.add_feature(:scenario_automation)
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      Helpdesk::Ticket.any_instance.stubs(:service_task?).returns(true)
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      assert_response 400
      match_json([bad_request_error_pattern('id', :fsm_ticket_scenario_failure)])
    ensure
      @account.revoke_feature(:scenario_automation)
      Helpdesk::Ticket.any_instance.unstub(:service_task?)
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_execute_scenario_without_ticket_access
      @account.add_feature(:scenario_automation)
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
    ensure
      @account.revoke_feature(:scenario_automation)
    end

    def test_execute_scenario_without_scenario_access
      @account.add_feature(:scenario_automation)
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      ScenarioAutomation.any_instance.stubs(:check_user_privilege).returns(false)
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      ScenarioAutomation.any_instance.unstub(:check_user_privilege)
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :inaccessible_value, resource: :scenario, attribute: :scenario_id)])
    ensure
      @account.revoke_feature(:scenario_automation)
    end

    def test_execute_scenario_failure_with_closure_action
      @account.add_feature(:scenario_automation)
      scenario = create_scn_automation_rule(scenario_automation_params.merge(close_action_params))
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      ticket_field1 = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field2 = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, true) }
      t = create_ticket
      put :execute_scenario, construct_params({ version: 'private', id: t.display_id }, scenario_id: scenario.id)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received),
                  bad_request_error_pattern(custom_field_error_label(ticket_field1.label), :datatype_mismatch, expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received),
                  bad_request_error_pattern(custom_field_error_label(ticket_field2.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
    ensure
      @account.revoke_feature(:scenario_automation)
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
    end

    def test_execute_scenario_for_nested_dropdown_with_closure_action_without_dropdown_value_present
      @account.add_feature(:scenario_automation)
      scenario = create_scn_automation_rule(scenario_automation_params.merge(close_action_params))
      ticket_field1 = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field2 = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, true) }
      t = create_ticket({custom_field: { ticket_field1.name => 'Sample Text', ticket_field2.name => 'USA' }})
      put :execute_scenario, construct_params({ version: 'private', id: t.display_id }, scenario_id: scenario.id)
      assert_response 400
    ensure
      @account.revoke_feature(:scenario_automation)
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
    end

    def test_execute_scenario_success_with_closure_action
      @account.add_feature(:scenario_automation)
      scenario = create_scn_automation_rule(scenario_automation_params.merge(close_action_params))
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      ticket_field1 = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field2 = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, true) }
      group = create_group(@account)
      t = create_ticket({custom_field: { ticket_field1.name => 'Sample Text', ticket_field2.name => CUSTOM_FIELDS_CHOICES.sample }}, group)
      put :execute_scenario, construct_params({ version: 'private', id: t.display_id }, scenario_id: scenario.id)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
      scenario_activities = scenario[:action_data]
      scenario_activities.map do |hash|
        if hash[:comment]
          hash.delete(:comment)
        end
      end
      assert_json_match response.api_meta[:activities], scenario_activities
    ensure
      @account.revoke_feature(:scenario_automation)
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
    end

    def test_execute_scenario_with_closure_of_parent_ticket_failure
      @account.add_feature(:scenario_automation)
      scenario = create_scn_automation_rule(scenario_automation_params.merge(close_action_params))
      parent_ticket = create_ticket
      child_ticket = create_ticket
      Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      put :execute_scenario, construct_params({ version: 'private', id: parent_ticket.display_id }, scenario_id: scenario.id)
      assert_response 400
      match_json([bad_request_error_pattern('status', :unresolved_child)])
    ensure
      @account.revoke_feature(:scenario_automation)
      Helpdesk::Ticket.any_instance.unstub(:child_ticket?)
      Helpdesk::Ticket.any_instance.unstub(:associates)
      Helpdesk::Ticket.any_instance.unstub(:association_type)
    end

    def test_execute_scenario_with_closure_of_parent_ticket_success
      @account.add_feature(:scenario_automation)
      scenario = create_scn_automation_rule(scenario_automation_params.merge(close_action_params))
      parent_ticket = create_ticket
      child_ticket = create_ticket(status: 5)
      Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates_rdb).returns(parent_ticket.display_id)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      put :execute_scenario, construct_params({ version: 'private', id: parent_ticket.display_id }, scenario_id: scenario.id)
      assert_response 200
      match_json(ticket_show_pattern(parent_ticket.reload))
      scenario_activities = scenario[:action_data]
      scenario_activities.map do |hash|
        if hash[:comment]
          hash.delete(:comment)
        end
      end
      assert_json_match response.api_meta[:activities], scenario_activities
    ensure
      @account.revoke_feature(:scenario_automation)
      Helpdesk::Ticket.any_instance.unstub(:child_ticket?)
      Helpdesk::Ticket.any_instance.unstub(:associates)
      Helpdesk::Ticket.any_instance.unstub(:association_type)
    end

    def test_execute_scenario
      @account.add_feature(:scenario_automation)
      scenario = create_scn_automation_rule(scenario_automation_params.merge({action_data: [{:name=>"ticket_type", :value=>"Question"},
                                                                                            {:name=>"add_comment", :comment=>"hey test1"},
                                                                                            {:name=>"add_tag", :value=>"hey,tag1,tag2"},
                                                                                            {:name=>"add_watcher", :value=>[8, 1]},
                                                                                            {:name=>"add_comment", :comment=>"hey test3"}]}));
      ticket = create_ticket(ticket_params_hash)
      put :execute_scenario, construct_params({ version: 'private', id: ticket.display_id }, scenario_id: scenario.id)
      assert_response 200
      match_json(ticket_show_pattern(ticket.reload))
      scenario_activities = scenario[:action_data]
      scenario_activities.map do |hash|
        if hash[:comment]
          hash.delete(:comment)
        end
      end
      assert_json_match response.api_meta[:activities], scenario_activities
    ensure
      @account.revoke_feature(:scenario_automation)
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

      assert_response 200
      match_json(latest_note_as_ticket_pattern(ticket))
    end

    def test_latest_note_ticket_with_private_note
      ticket = create_ticket
      note = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:note], true))
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    end

    def test_latest_note_ticket_with_public_note
      ticket = create_ticket
      note = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:note]))
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    end

    def test_latest_note_ticket_with_reply
      ticket = create_ticket
      reply = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:email]))
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
    #     b. outbound email reply
    #     c. shared ownership enabled
    #     d. twitter reply
    #     e. fb reply
    #     f. phone only contact
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

    def test_split_note_with_outbound_email_reply
      ticket = create_ticket(source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email])
      reply = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:email]))
      put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: reply.id }, false)
      assert_response 200
      assert_equal 1, JSON.parse(response.body)['source']
    end

    def test_split_ticket_with_shared_ownership_enabled
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        group_restricted_agent = add_agent_to_group(group_id = @internal_group.id,
                                                    ticket_permission = 2, role_id = @account.roles.first.id)
        ticket = create_ticket({ status: @status.status_id, source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email], internal_agent_id: @internal_agent.id }, nil, @internal_group)
        login_as(@internal_agent)
        reply = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:email]))
        put :split_note, construct_params({ version: 'private', id: ticket.display_id, note_id: reply.id }, false)
        assert_response 200
        assert_equal 1, JSON.parse(response.body)['source']
      end
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

    def test_split_note_with_phone_only_contact_reply
      user = add_new_user_without_email(@account)
      params_hash = {
        requester_id: user.id,
        source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:phone]
      }
      ticket = create_ticket(params_hash)
      note = create_normal_reply_for(ticket)
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

    def test_update_properties_without_ticket_access
      ticket = create_ticket
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      dt = 10.days.from_now.utc.iso8601
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      update_group = create_group_with_agents(@account, agent_list: [agent.id])
      tags = Faker::Lorem.words(3).uniq
      params_hash = { due_by: dt, responder_id: agent.id, status: 2, priority: 4, group_id: update_group.id, tags: tags }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
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

    def test_update_properties_with_requester_having_two_emails
      sample_requester = add_user_with_multiple_emails(@account, 2)
      sample_requester_email = sample_requester.emails[1]
      description = Faker::Lorem.paragraph
      subject = Faker::Lorem.words(10).join(' ')
      params_hash = {
        subject: subject,
        description: description,
        email: sample_requester_email,
        requester_id: sample_requester.id
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      response_body = JSON.parse(response.body)
      assert_equal response_body['sender_email'], sample_requester_email
      assert_equal response_body['requester_id'], sample_requester.id
    end

    def test_sender_email_nil_when_requester_email_is_nil
      sample_requester = add_new_user_without_email(@account)
      description = Faker::Lorem.paragraph
      subject = Faker::Lorem.words(10).join(' ')
      params_hash = {
        subject: subject,
        description: description,
        requester_id: sample_requester.id
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      response_body = JSON.parse(response.body)
      assert_equal response_body['sender_email'], nil
      assert_equal response_body['requester_id'], sample_requester.id
    end

    def test_update_properties_with_subject_description
      ticket = create_ticket
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = {
        subject: subject,
        description: description,
        attachment_ids: attachment_ids
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal attachment_ids, ticket.attachment_ids
    end

    def test_update_properties_with_subject_description_requester_source_phone
      ticket = create_ticket(source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:phone])
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      user = add_new_user(@account)
      requester_id = user.id
      sender_email = user.email
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = {
        subject: subject,
        description: description,
        requester_id: requester_id,
        attachment_ids: attachment_ids
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal requester_id, ticket.requester_id
      assert_equal sender_email, ticket.sender_email
      assert_equal attachment_ids, ticket.attachment_ids
    end

    def test_update_properties_with_subject_description_requester_source_email
      ticket = create_ticket(source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:email])
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      user = add_new_user(@account)
      requester_id = user.id
      sender_email = user.email
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = {
        subject: subject,
        description: description,
        requester_id: requester_id,
        attachment_ids: attachment_ids
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal requester_id, ticket.requester_id
      assert_equal sender_email, ticket.sender_email
      assert_equal attachment_ids, ticket.attachment_ids
    end
    def test_update_properties_with_subject_description_requester_with_default_company
      ticket = create_ticket
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      sample_requester = get_user_with_default_company
      requester_id = sample_requester.id
      sender_email = sample_requester.email
      company_id = sample_requester.user_companies.first.company_id if sample_requester.user_companies.first.present?
      params_hash = {
        subject: subject,
        description: description,
        requester_id: requester_id
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal requester_id, ticket.requester_id
      assert_equal ticket.company_id, sample_requester.company_id
      assert_equal company_id, ticket.company_id
      assert_equal sender_email, ticket.sender_email
    end

    def test_update_properties_with_subject_description_requester_with_multiple_company
      Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
      ticket = create_ticket
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      sample_requester = get_user_with_multiple_companies
      requester_id = sample_requester.id
      sender_email = sample_requester.email
      company_id = sample_requester.user_companies.where(default: false).first.company.id
      params_hash = {
        subject: subject,
        description: description,
        requester_id: requester_id,
        company_id: company_id
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal requester_id, ticket.requester_id
      assert_equal company_id, ticket.company_id
      assert_equal sender_email, ticket.sender_email
      ensure
        Account.any_instance.unstub(:multiple_user_companies_enabled?)
    end

    def test_update_properties_with_subject_description_invalid_requester
      ticket = create_ticket
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      sample_requester = add_new_user(@account)
      requester_id = sample_requester.id + 10
      params_hash = {
        subject: subject,
        description: description,
        requester_id: requester_id
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:requester_id,'There is no contact matching the given requester_id')])
    end

    def test_update_properties_with_subject_description_requester_with_invalid_company
      Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
      ticket = create_ticket
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      sample_requester = get_user_with_multiple_companies
      requester_id = sample_requester.id
      company_id = Company.create(name: Faker::Name.name, account_id: @account.id).id
      params_hash = {
        subject: subject,
        description: description,
        requester_id: requester_id,
        company_id: company_id
      }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:company_id,'The requester does not belong to the specified company')])
      ensure
        Account.any_instance.unstub(:multiple_user_companies_enabled?)
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
      Helpdesk::Ticket.any_instance.stubs(:associates_rdb).returns(parent_ticket.display_id)
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

    def test_update_properties_with_required_default_field_blank
      Helpdesk::TicketField.where(name: 'group').update_all(required: true)
      group = create_group(@account)
      t = create_ticket({}, group)
      params_hash = { group_id: nil }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required: false)
    end

    def test_update_properties_with_required_default_field_blank_in_db
      Helpdesk::TicketField.where(name: 'group').update_all(required: true)
      t = create_ticket
      params_hash = { status: 3 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required: false)
    end

    def test_update_properties_closure_status_with_required_for_closure_default_field_blank
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      group = create_group(@account)
      t = create_ticket({}, group)
      params_hash = { status: 5, group_id: nil }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_closure_status_with_required_for_closure_default_field_blank_in_db
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      t = create_ticket
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_default_field_blank
      group = create_group(@account)
      t = create_ticket({ status: 5 }, group)
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      params_hash = { group_id: nil }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_default_field_blank_in_db
      t = create_ticket(status: 5)
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_closure_and_type_updated_with_dependent_field_with_one_level_filled
      sections = [
        {
          title: 'section5789',
          value_mapping: ['Question'],
          ticket_fields: ['dependent']
        }
      ]
      section_ids = create_section_fields(3, sections, false, true, "_123456891", 28)
      @account.reload
      dependent_field = @account.section_fields.where(section_id: section_ids[0])[0].ticket_field
      dependent_field.update_attribute(:required, true)
      params = ticket_params_hash.merge(type: 'Question', custom_field: {})
      params[:custom_field][dependent_field.name] = 'USA'
      params.delete('fr_due_by')
      params.delete('due_by')
      ticket = create_ticket(params)
      params_hash = update_ticket_params_hash.merge(type: 'Problem', status: 5)
      params_hash.delete(:fr_due_by)
      params_hash.delete(:due_by)
      Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 200
      dependent_field.update_attribute(:required, false)
    end

    def test_update_properties_with_property_type_with_date_field_and_type_changed
      sections = construct_sections('type')
      create_section_fields(3, sections, false)
      new_custom_field = create_custom_field('name', 'text')
      custom_field1 = Helpdesk::TicketField.where(field_type: 'custom_date').select(&:section_field?)
      custom_field2 = Helpdesk::TicketField.where(field_type: 'custom_number').select(&:section_field?)
      ticket = create_ticket
      ticket.update_attribute(:ticket_type, 'Problem')
      ticket.update_attribute(:custom_field, custom_field1[0].name.to_sym => '2018-02-21')
      ticket.update_attribute(:custom_field, custom_field2[0].name.to_sym => 45)
      params_hash = {
        type: 'Refund'
      }
      Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 200
      params = {
        custom_fields: {}
      }
      params[:custom_fields][new_custom_field.label.to_sym] = 'Padmashri'
      params[:custom_fields][custom_field1[0].label.to_sym] = '2018-02-21'
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 200
    end

    def test_update_closure_and_type_updated_with_dependent_field_with_two_levels_filled
      sections = [
        {
          title: 'section5',
          value_mapping: ['Question'],
          ticket_fields: ['dependent']
        }
      ]
      section_ids = create_section_fields(3, sections, false, true, '_1234568910', 31)
      @account.reload
      dependent_field = @account.section_fields.where(section_id: section_ids[0])[0].ticket_field
      dependent_field.update_attribute(:required, true)
      params = ticket_params_hash.merge(custom_field: {}, type: 'Question')
      params[:custom_field][dependent_field.name] = 'USA'
      child_level_fields = Helpdesk::TicketField.where(parent_id: dependent_field.id)
      params[:custom_field][child_level_fields[0].name.to_sym] = 'California'
      params.delete('fr_due_by')
      params.delete('due_by')
      @account.reload
      Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
      ticket = create_ticket(params)
      params_hash = update_ticket_params_hash.merge(type: 'Problem', status: 5)
      params_hash.delete(:fr_due_by)
      params_hash.delete(:due_by)
      Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 200
      dependent_field.update_attribute(:required, false)
    end

    def test_update_closure_and_type_updated_with_dependent_field_with_all_levels_filled
      sections = [
        {
          title: 'section56',
          value_mapping: ['Question'],
          ticket_fields: ['dependent']
        }
      ]
      section_ids = create_section_fields(3, sections, false, true, "_12345689", 25)
      dependent_field = @account.section_fields.where(section_id: section_ids[0])[0].ticket_field
      dependent_field.update_attribute(:required, true)
      params = ticket_params_hash.merge(custom_field: {}, type: 'Question')
      params[:custom_field][dependent_field.name] = 'USA'
      child_level_fields = dependent_field.child_levels
      params[:custom_field][child_level_fields[0].name.to_sym] = 'California'
      params[:custom_field][child_level_fields[1].name.to_sym] = 'Burlingame'
      @account.reload
      params.delete(:fr_due_by)
      params.delete(:due_by)
      ticket = create_ticket(params)
      params_hash = update_ticket_params_hash.merge(type: 'Problem', status: 5)
      params_hash.delete(:fr_due_by)
      params_hash.delete(:due_by)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      last_ticket = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(last_ticket))
      assert_response 200
      dependent_field.update_attribute(:required, false)
    end


    def test_update_properties_with_required_custom_non_dropdown_field_blank_in_db
      t = create_ticket
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required, true)
      params_hash = { status: 3 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required, false)
    end

    def test_update_properties_closure_status_with_required_for_closure_custom_non_dropdown_field_blank_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      t = create_ticket
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :datatype_mismatch, expected_data_type: :String)])
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_custom_non_dropdown_field_blank_in_db
      t = create_ticket(status: 5)
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_with_required_custom_dropdown_field_blank_in_db
      t = create_ticket
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      ticket_field.update_attribute(:required, true)
      params_hash = { status: 3 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required, false)
    end

    def test_update_properties_closure_status_with_required_for_closure_custom_dropdown_field_blank_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      t = create_ticket
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_custom_dropdown_field_blank_in_db
      t = create_ticket(status: 5)
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_with_required_default_field_with_incorrect_value
      Helpdesk::TicketField.where(name: 'group').update_all(required: true)
      group = create_group(@account)
      t = create_ticket({}, group)
      params_hash = { group_id: group.id + 10 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required: false)
    end

    def test_update_properties_with_required_default_field_with_incorrect_value_in_db
      Helpdesk::TicketField.where(name: 'group').update_all(required: true)
      group = create_group(@account)
      t = create_ticket
      t.update_attributes(group_id: group.id + 10)
      params_hash = { status: 3 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required: false)
    end

    def test_update_properties_closure_status_with_required_for_closure_default_field_with_incorrect_value
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      group = create_group(@account)
      t = create_ticket({}, group)
      params_hash = { status: 5, group_id: group.id + 10 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_closure_status_with_required_for_closure_default_field_with_incorrect_value_in_db
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      group = create_group(@account)
      t = create_ticket
      t.update_attributes(group_id: group.id + 10)
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_default_field_with_incorrect_value
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      group = create_group(@account)
      t = create_ticket({ status: 5 }, group)
      params_hash = { group_id: group.id + 10 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id)])
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_default_field_with_incorrect_value_in_db
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      group = create_group(@account)
      t = create_ticket(status: 5)
      t.update_attributes(group_id: group.id + 10)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_with_required_custom_non_dropdown_field_blank_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
      ticket_field.update_attribute(:required, true)
      t = create_ticket(custom_field: { ticket_field.name => 'Sample Text' })
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required, false)
    end

    def test_update_properties_closure_status_with_required_for_closure_custom_non_dropdown_field_blank_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      t = create_ticket(custom_field: { ticket_field.name => 'Sample Text' })
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :invalid_date, code: :missing_field, accepted: 'yyyy-mm-dd')])
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
      t = create_ticket(status: 5, custom_field: { ticket_field.name => 'Sample Text' })
      ticket_field.update_attribute(:required_for_closure, true)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_with_required_custom_dropdown_field_blank_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      ticket_field.update_attribute(:required, true)
      t = create_ticket(custom_field: { ticket_field.name => 'invalid_choice' })
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required, false)
    end

    def test_update_properties_closure_status_with_required_for_closure_custom_dropdown_field_blank_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      t = create_ticket(custom_field: { ticket_field.name => 'invalid_choice' })
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_closure_status_with_required_for_closure_custom_nested_dropdown_field_blank_with_incorrect_value_in_db
      t = create_ticket(requester_id: @agent.id)
      params = { status: 5 }
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params)
      assert_response 400
      ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_of_closed_tickets_with_required_for_closure_custom_dropdown_field_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      t = create_ticket(status: 5, custom_field: { ticket_field.name => 'invalid_choice' })
      ticket_field.update_attribute(:required_for_closure, true)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_update_properties_with_non_required_default_field_blank
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
      group = create_group(@account)
      t = create_ticket({}, group)
      params_hash = { group_id: nil }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    ensure
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
    end

    def test_update_properties_with_non_required_default_field_with_incorrect_value
      t = create_ticket
      group = create_group(@account)
      params_hash = { priority: 1000 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('priority', :not_included, list: ApiTicketConstants::PRIORITIES.join(','))])
    end

    def test_update_properties_with_non_required_default_field_with_incorrect_value_in_db
      ticket_ids = []
      t = create_ticket(type: 'Sample')
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    end

    def test_update_properties_with_non_required_custom_non_dropdown_field_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
      t = create_ticket(custom_field: { ticket_field.name => 'Sample Text' })
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    end

    def test_update_properties_with_non_required_default_field_with_invalid_value
      group = create_group(@account)
      t = create_ticket({}, group)
      params_hash = { group_id: group.id + 10 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id)])
    end

    def test_update_properties_with_non_required_default_field_with_invalid_value_in_db
      group = create_group(@account)
      t = create_ticket
      t.update_attributes(group_id: group.id + 10)
      params_hash = { status: 3 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    end

    def test_update_properties_with_non_required_custom_dropdown_field_with_incorrect_value_in_db
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      t = create_ticket(custom_field: { ticket_field.name => 'invalid_choice' })
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(t.reload))
    end

    def test_update_properties_with_cloud_files
      ticket = create_ticket
      cloud_file_params = [{ name: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }]
      params_hash = { cloud_files: cloud_file_params }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal 1, ticket.cloud_files.count
    end

    def test_update_properties_with_empty_cloud_files
      # update properties empty cloud files
      ticket = create_ticket
      cloud_file_params = []
      params_hash = { cloud_files: cloud_file_params }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal 0, ticket.cloud_files.count
    end

    def test_update_properties_with_cloud_files_id
      ticket = create_ticket
      cloud_file_params = [{ id: 2, name: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }]
      params_hash = { cloud_files: cloud_file_params }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      ticket.reload
    end

    def test_update_properties_with_cloud_files_and_attachments
      ticket = create_ticket
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      cloud_file_params = [{ name: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }, { name: 'image2.jpg', url: 'https://www.dropbox.com/image2.jpg', application_id: 20 }]
      params_hash = { cloud_files: cloud_file_params, attachment_ids: attachment_ids }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      ticket.reload
      assert_equal 2, ticket.cloud_files.count
      assert_equal attachment_ids, ticket.attachment_ids
    end

    def test_update_properties_with_new_tag_without_privilege
      ticket = create_ticket
      tags = Faker::Lorem.words(3).uniq
      tags = tags.map do |tag|
      #Timestamp added to make sure tag names are new
        tag = "#{tag}#{Time.now.to_i}"
        assert_equal @account.tags.map(&:name).include?(tag), false
        tag
      end
      User.current.reload
      remove_privilege(User.current, :create_tags)
      params_hash = { tags: tags }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      assert_equal ticket.tags.count, 0
      add_privilege(User.current, :create_tags)
    end

    def test_update_properties_with_existing_tag_without_privilege
      ticket = create_ticket
      tag = Faker::Lorem.word
      @account.tags.create(:name => tag) unless @account.tags.map(&:name).include?(tag)
      User.current.reload
      remove_privilege(User.current, :create_tags)
      params_hash = { tags: [tag] }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      assert_equal ticket.tags.count, 1
      add_privilege(User.current, :create_tags)
    end

    def test_update_properties_with_tag_with_privilege
      ticket = create_ticket
      tags = Faker::Lorem.words(3).uniq
      tags = tags.map do |tag|
      #Timestamp added to make sure tag names are new
        tag = "#{tag}#{Time.now.to_i}"
        assert_equal @account.tags.map(&:name).include?(tag), false
        tag
      end
      params_hash = { tags: tags }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      assert_equal tags.count, ticket.tags.count
    end

    def test_update_properties_with_inline_attachment_ids
      t = create_ticket
      inline_attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      params_hash = { inline_attachment_ids: inline_attachment_ids }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      t = Account.current.tickets.find_by_display_id(t.display_id)
      assert_equal inline_attachment_ids.size, t.inline_attachments.size
    end

    def test_update_properties_with_invalid_inline_attachment_ids
      t = create_ticket
      inline_attachment_ids, valid_ids, invalid_ids = [], [], []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
      end
      invalid_ids << 0
      BULK_ATTACHMENT_CREATE_COUNT.times do
        valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      inline_attachment_ids = invalid_ids + valid_ids
      params_hash = { inline_attachment_ids: inline_attachment_ids }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
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
      match_json(ticket_show_pattern(ticket.reload))
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
      match_json(ticket_show_pattern(ticket.reload))
      Account.current.features.twitter.create if twitter_enabled
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Account.unstub(:current)
    end

    def test_show_with_full_requester_info
      t = create_ticket
      sample_requester = get_user_with_multiple_companies
      t.update_attributes(requester: sample_requester)
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      response_body = JSON.parse(response.body)
      assert_equal ticket_requester_pattern(t.requester), response_body['requester'].deep_symbolize_keys
      match_json(ticket_show_pattern(t, nil, true))
    end

    def test_ticket_with_secret_id
      Account.current.launch(:agent_collision_revamp)
      t = create_ticket
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(t, nil, true))
      Account.current.rollback(:agent_collision_revamp)
    end

    def test_show_with_restricted_requester_info
      t = create_ticket
      remove_privilege(User.current, :view_contacts)
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(t, nil, true))
      add_privilege(User.current, :view_contacts)
    end

    def test_show_with_agent_as_requester
      t = create_ticket(requester_id: add_test_agent(@account, role: Role.find_by_name('Agent').id).id)
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(t, nil, true))
    end

    # Test date format for requester and company sideload
    def test_show_with_full_requester_info_and_custom_date
      company_field = create_company_field(company_params(type: 'date', field_type: 'custom_date', label: 'Company date', name: 'cf_company_date', field_options: { 'widget_position' => 12 }))
      contact_field = create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Requester Date', name: 'cf_requester_date', required_for_agent: true, editable_in_signup: true, field_options: { 'widget_position' => 12 }))
      time_now = Time.zone.now
      company = create_company
      company.update_attributes(custom_field: {cf_company_date: time_now})
      user = add_new_user(@account, { customer_id: company.id, custom_fields: { cf_requester_date: time_now}})
      ticket = create_ticket(requester_id: user.id)
      Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
      get :show, controller_params(version: 'private', id: ticket.display_id, include: 'requester,company')
      assert_response 200
      res = JSON.parse(response.body)
      assert_equal res['nr_due_by'], nil
      assert_equal res['nr_escalated'], false
      ticket_date_format = Time.now.in_time_zone(@account.time_zone).strftime('%F')
      contact_field.destroy
      company_field.destroy
      assert_equal ticket_date_format, res['requester']['custom_fields']['requester_date']
      assert_equal ticket_date_format, res['company']['custom_fields']['company_date']
    ensure
      Account.any_instance.unstub(:next_response_sla_enabled?)
    end

    def test_show_with_requester
      user_tags = ['tag1','tags2']
      tag_field = @account.contact_form.default_fields.find_by_name(:tag_names)
      tag_field.update_attributes(field_options: { 'widget_position' => 10 })
      user = add_new_user(@account, tag_names: user_tags.join(','), tags: user_tags.join(','))
      user.reload
      t = create_ticket(requester_id: user.id)
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(t, nil, true))
      assert_equal user_tags.size, t.requester.tags.size
      tag_field.update_attributes(field_options: nil)
    end

    def test_show_with_valid_meta
      t = create_ticket(requester_id: add_test_agent(@account, role: Role.find_by_name('Agent').id).id)

      # Adding meta note
      meta_data = "created_by: 1\ntime: 2017-03-14 15:13:13 +0530\nuser_agent: Mozilla/5.0"
      meta_note = t.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token['meta'])

      if meta_note
        meta_note.note_body_attributes = { body: meta_data }
      else
        meta_note = t.notes.build(source: Account.current.helpdesk_sources.note_source_keys_by_token['meta'],
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
      meta_note = t.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token['meta'])

      if meta_note
        meta_note.note_body_attributes = { body: meta_data }
      else
        meta_note = t.notes.build(source: Account.current.helpdesk_sources.note_source_keys_by_token['meta'],
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

    def test_update_closure_status_without_notification
      t = create_ticket
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      update_params = { custom_fields: { 'test_custom_text' => 'Hello' }, status: 5, skip_close_notification: true }
      params_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(update_params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      t = Account.current.tickets.find_by_display_id(t.display_id)
      match_json(ticket_show_pattern(t))
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
      Helpdesk::Ticket.any_instance.stubs(:associates_rdb).returns(parent_ticket.display_id)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
      Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
      params_hash = { status: 4 }
      put :update, construct_params({ version: 'private', id: parent_ticket.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(parent_ticket.reload))
      assert_equal 4, parent_ticket.status
    end

    def test_update_with_attachment_ids
      t = create_ticket
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = update_ticket_params_hash.merge(attachment_ids: attachment_ids)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      t = Account.current.tickets.find_by_display_id(t.display_id)
      match_json(ticket_show_pattern(t))
      assert_equal attachment_ids.size, t.attachments.count
    end

    def test_update_with_cloud_files
      t = create_ticket
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      params_hash = update_ticket_params_hash.merge(cloud_files: cloud_file_params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
      t = Account.current.tickets.find_by_display_id(t.display_id)
      match_json(ticket_show_pattern(t))
      assert_equal 1, t.cloud_files.count
    end

    def test_update_with_shared_attachments
      t = create_ticket
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params_hash = update_ticket_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      stub_attachment_to_io do
        put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      end
      assert_response 200
      t = Account.current.tickets.find_by_display_id(t.display_id)
      match_json(ticket_show_pattern(t))
      assert_equal 1, t.attachments.count
    end

    def test_update_with_section_fields_type_as_parent
      sections = construct_sections('type')
      type_field_id = @account.ticket_fields.find_by_field_type('default_ticket_type').id
      create_section_fields(type_field_id, sections)
      t = create_ticket
      params = { custom_fields: {}, type: 'Incident' }
      %w(paragraph dropdown).each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      params_hash = update_ticket_params_hash.merge(params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_response 200
    ensure
      clear_field_options
    end

    def test_update_with_associated_company_deleted
      new_user = add_new_user(@account)
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      new_user.user_companies.create(company_id: company.id, default: true)
      sample_requester = new_user.reload
      company_id = sample_requester.company_id
      ticket = create_ticket({ requester_id: sample_requester.id, company_id: company_id })
      @account.companies.find_by_id(company_id).destroy
      params_hash = { status: 5 }
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
      match_json(ticket_show_pattern(ticket.reload))
      assert_equal 5, ticket.status
    end

    def test_update_requester_having_multiple_companies
      new_user = add_new_user(@account)
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      new_user.user_companies.create(company_id: company.id, default: true)
      other_company = create_company
      new_user.user_companies.create(company_id: other_company.id)
      sample_requester = new_user.reload
      company_id = sample_requester.company_id
      ticket = create_ticket({ requester_id: sample_requester.id, company_id: company_id })
      @account.companies.find_by_id(company_id).destroy
      params_hash = { status: 5 }
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 200
    end

    def test_update_with_section_fields_custom_dropdown_as_parent
      dd_field_id = create_custom_field_dropdown_with_sections.id
      sections = construct_sections('section_custom_dropdown')
      create_section_fields(dd_field_id, sections)
      t = create_ticket
      params = { custom_fields: { section_custom_dropdown: 'Choice 3' } }
      ['paragraph'].each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      params_hash = update_ticket_params_hash.merge(params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_response 200
    ensure
      clear_field_options
    end

    def test_update_with_section_fields_parent_custom_dropdown_and_child_dependent
      dropdown_value = CUSTOM_FIELDS_CHOICES.sample
      sections = [
        {
          title: 'section1',
          value_mappingvalue_mapping: [dropdown_value],
          ticket_fields: ['dependent']
        }
      ]
      cust_dropdown_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      create_section_fields(cust_dropdown_field.id, sections, false)

      t = create_ticket
      params = { custom_fields: { test_custom_dropdown: dropdown_value } }
      ['paragraph'].each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      params_hash = update_ticket_params_hash.merge(params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_response 200
    ensure
      clear_field_options
    end

    def test_export_csv_with_no_params
      rand(2..10).times do
        add_new_user(@account)
      end
      post :export_csv, construct_params({ version: 'private' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('format', :missing_field),
                  bad_request_error_pattern('date_filter', :missing_field),
                  bad_request_error_pattern('ticket_state_filter', :missing_field),
                  bad_request_error_pattern('query_hash', :missing_field)])
    end

    def test_export_csv_invalid_params_without_privilege
      contact_fields = @account.contact_form.fields
      company_fields = @account.company_form.fields
      params_hash = { ticket_fields: { id: rand(2..10) }, contact_fields: { display_id: rand(2..10) }, query_hash: [{ 'condition' => 'responder_id', 'ff_name' => 'default' }],
                      company_fields: { number: rand(2..10) }, format: Faker::Lorem.word, date_filter: Faker::Lorem.word,
                      ticket_state_filter: Faker::Lorem.word, start_date: 6.days.ago.to_s, end_date: Time.zone.now.to_s }
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:ticket_fields, :not_included, list: ticket_export_fields.join(',')),
                  bad_request_error_pattern(:contact_fields, :not_included, list: %i(name phone mobile fb_profile_id contact_id).join(',')),
                  bad_request_error_pattern(:company_fields, :not_included, list: %i(name).join(',')),
                  bad_request_error_pattern(:format, :not_included, list: %w(csv xls).join(',')),
                  bad_request_error_pattern(:date_filter, :not_included, list: TicketConstants::CREATED_BY_NAMES_BY_KEY.keys.map(&:to_s).join(',')),
                  bad_request_error_pattern(:ticket_state_filter, :not_included, list: TicketConstants::STATES_HASH.keys.map(&:to_s).join(',')),
                  bad_request_error_pattern(:start_date, :invalid_date, accepted: 'combined date and time ISO8601'),
                  bad_request_error_pattern(:end_date, :invalid_date, accepted: 'combined date and time ISO8601'),
                  bad_request_error_pattern(:"query_hash[0]", :"operator: Mandatory attribute missing & value: Mandatory attribute missing")])
      User.any_instance.unstub(:privilege?)
    end

    def test_export_csv_without_privilege
      @account.rollback(:silkroad_export)
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
      export_fields = Helpdesk::TicketModelExtension.allowed_ticket_export_fields
      params_hash = { ticket_fields: export_fields.map { |i| { i[1] => I18n.t(i[0]) } if i[5] == :ticket }.compact.inject(&:merge),
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      User.any_instance.unstub(:privilege?)
    end

    def test_export_csv_with_privilege
      @account.rollback(:silkroad_export)
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:export_customers).returns(true)
      @account.launch(:ticket_contact_export)
      create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Address', name: 'cf_address'))
      create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Location', name: 'cf_location', editable_in_signup: 'true'))
      contact_fields = @account.contact_form.fields.map(&:name) - %i(name phone mobile fb_profile_id contact_id)
      company_fields = @account.company_form.fields.map(&:name) - %i(name)
      params_hash = { ticket_fields: { display_id: rand(2..10) }, contact_fields: { custom_fields: { location: Faker::Lorem.word } },
                      company_fields: { custom_fields: { address: Faker::Lorem.word } },
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      User.any_instance.unstub(:privilege?)
      @account.rollback(:ticket_contact_export)
    end

    def test_export_csv_with_privilege_filter_with_comma_values
      @account.rollback(:silkroad_export)
      @account.launch(:wf_comma_filter_fix)
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:export_customers).returns(true)
      @account.launch(:ticket_contact_export)
      create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Address', name: 'cf_address'))
      create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Location', name: 'cf_location', editable_in_signup: 'true'))
      contact_fields = @account.contact_form.fields.map(&:name) - %i[name phone mobile fb_profile_id contact_id]
      company_fields = @account.company_form.fields.map(&:name) - %i[name]
      ticket_field = create_custom_field_dropdown('test_export_csv', ['Chennai, In', 'bangalore'])
      params_hash = { ticket_fields: { display_id: rand(2..10) }, contact_fields: { custom_fields: { location: Faker::Lorem.word } },
                      company_fields: { custom_fields: { address: Faker::Lorem.word } },
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'test_export_csv', 'operator' => 'is_in', 'ff_name' => 'test_export_csv', 'value' => [ticket_field.picklist_values.first.value] }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
    ensure
      User.any_instance.unstub(:privilege?)
      @account.rollback(:ticket_contact_export)
      @account.rollback(:wf_comma_filter_fix)
      ticket_field.destroy
    end

    def test_export_csv_monitor_by_me
      @account.rollback(:silkroad_export)
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
      export_fields = Helpdesk::TicketModelExtension.allowed_ticket_export_fields
      params_hash = { ticket_fields: export_fields.map { |i| { i[1] => I18n.t(i[0]) } if i[5] == :ticket }.compact.inject(&:merge),
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [], filter_name: 'monitored_by' }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      jobs = ::Tickets::Export::TicketsExport.jobs
      assert jobs.last['args'].first['filter_name'] == 'monitored_by'
      assert jobs.last['args'].first['data_hash'].nil?
      User.any_instance.unstub(:privilege?)
    end

    def test_export_csv_with_invalid_filtername
      @account.rollback(:silkroad_export)
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
      User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
      export_fields = Helpdesk::TicketModelExtension.allowed_ticket_export_fields
      params_hash = { ticket_fields: export_fields.map { |i| { i[1] => I18n.t(i[0]) } if i[5] == :ticket }.compact.inject(&:merge),
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [], filter_name: 'test' }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:filter_name, "It should be one of these values: '#{TicketConstants::DEFAULT_FILTER_EXPORT.join(',')}'", code: 'invalid_value')))
      User.any_instance.unstub(:privilege?)
    end

    def test_export_csv_with_limit_reach
      @account.rollback(:silkroad_export)
      export_ids = []
      DataExport.ticket_export_limit.times do
        export_entry = @account.data_exports.new(
                            :source => DataExport::EXPORT_TYPE["ticket".to_sym],
                            :user => User.current,
                            :status => DataExport::EXPORT_STATUS[:started]
                            )
        export_entry.save
        export_ids << export_entry.id
      end
      params_hash = { ticket_fields: { 'display_id' => 'id' },
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv',
                      date_filter: '30',
                      ticket_state_filter: 'resolved_at',
                      start_date: 6.days.ago.iso8601,
                      end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w[2 5] }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 429
      DataExport.where(:id => export_ids).destroy_all
    end

    def test_export_csv_without_privilege
      @account.rollback(:silkroad_export)
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(false)
      params_hash = { ticket_fields: { 'display_id' => 'id' },
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv',
                      date_filter: '30',
                      ticket_state_filter: 'resolved_at',
                      start_date: 6.days.ago.iso8601,
                      end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w[2 5] }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 403
      User.any_instance.unstub(:privilege?)
    end

    def test_export_csv_with_archive_export_limit_reached
      @account.rollback(:silkroad_export)
      export_ids = []
      @account.make_current
      DataExport.archive_ticket_export_limit.times do
        export_entry = @account.data_exports.new(
                            :source => DataExport::EXPORT_TYPE["archive_ticket".to_sym],
                            :user => User.current,
                            :status => DataExport::EXPORT_STATUS[:started]
                            )
        export_entry.save
        export_ids << export_entry.id
      end
      params_hash = { ticket_fields: { 'display_id' => 'id' },
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv',
                      date_filter: '30',
                      ticket_state_filter: 'resolved_at',
                      start_date: 6.days.ago.iso8601,
                      end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w[2 5] }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      DataExport.where(:id => export_ids).destroy_all
    end

    def test_export_csv_with_limit_reach_per_user
      @account.rollback(:silkroad_export)
      export_ids = []
      agent1 = add_test_agent(@account)
      DataExport.ticket_export_limit.times do
        export_entry = @account.data_exports.new(
                            :source => DataExport::EXPORT_TYPE["ticket".to_sym],
                            :user => agent1,
                            :status => DataExport::EXPORT_STATUS[:started]
                            )
        export_entry.save
        export_ids << export_entry.id
      end
      agent2 = add_test_agent(@account).make_current
      params_hash = { ticket_fields: { 'display_id' => 'id' },
                      contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                      company_fields: { 'name' => 'Company Name' },
                      format: 'csv',
                      date_filter: '30',
                      ticket_state_filter: 'resolved_at',
                      start_date: 6.days.ago.iso8601,
                      end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w[2 5] }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      DataExport.where(:id => export_ids).destroy_all
    end

    def test_export_inline_sidekiq_csv_with_no_tickets
      @account.rollback(:silkroad_export)
      RestClient::Request.any_instance.stubs(:execute).returns(ActionDispatch::TestResponse.new)
      @account.launch(:ticket_contact_export)
      2.times do
        create_ticket
      end
      initial_count = ticket_data_export(DataExport::EXPORT_TYPE[:ticket]).count
      params_hash = ticket_export_param.merge(start_date: 6.days.ago.iso8601, end_date: 5.days.ago.iso8601)
      Sidekiq::Testing.inline! do
        post :export_csv, construct_params({ version: 'private' }, params_hash)
      end
      current_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:ticket])
      assert_equal initial_count, current_data_exports.length
      @account.rollback(:ticket_contact_export)
    ensure
      RestClient::Request.any_instance.unstub(:execute)
    end

    def test_export_inline_sidekiq_csv_with_privilege
      @account.rollback(:silkroad_export)
      RestClient::Request.any_instance.stubs(:execute).returns(ActionDispatch::TestResponse.new)
      @account.launch(:ticket_contact_export)
      2.times do
        create_ticket
      end
      initial_count = ticket_data_export(DataExport::EXPORT_TYPE[:ticket]).count
      @account.ticket_fields.find_by_column_name("ff_date06").try(:destroy)
      create_custom_field('cf_fsm_appointment_start_time', 'date_time', '06', true)
      Account.reset_current_account
      @account = Account.first
      custom_fields = { cf_fsm_appointment_start_time: Time.zone.now.iso8601 }
      params_hash = ticket_export_param
      params_hash[:ticket_fields][:custom_fields] = custom_fields

      Sidekiq::Testing.inline! do
        post :export_csv, construct_params({ version: 'private' }, params_hash)
      end
      current_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:ticket])
      assert_equal initial_count, current_data_exports.length - 1
      assert_equal current_data_exports.last.status, DataExport::EXPORT_STATUS[:completed]
      assert current_data_exports.last.attachment.content_file_name.ends_with?('.csv')
      @account.rollback(:ticket_contact_export)
    ensure
      RestClient::Request.any_instance.unstub(:execute)
    end

    def test_export_inline_sidekiq_xls_with_privilege
      @account.rollback(:silkroad_export)
      RestClient::Request.any_instance.stubs(:execute).returns(ActionDispatch::TestResponse.new)
      @account.launch(:ticket_contact_export)
      2.times do
        create_ticket
      end
      initial_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:ticket])
      initial_count = initial_data_exports.count
      initial_data_exports_ids = initial_data_exports.map { |x| x.id }
      params_hash = ticket_export_param.merge(format: 'xls')
      Sidekiq::Testing.inline! do
        post :export_csv, construct_params({ version: 'private' }, params_hash)
      end
      current_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:ticket])
      assert_equal initial_count, current_data_exports.length - 1
      assert_equal current_data_exports.last.status, DataExport::EXPORT_STATUS[:completed]
      current_data_exports.reject! { |x| initial_data_exports_ids.include?(x.id) }
      assert current_data_exports.last.attachment.content_file_name.ends_with?('.xls')
      @account.rollback(:ticket_contact_export)
    ensure
      RestClient::Request.any_instance.unstub(:execute)
    end

    def test_update_with_company_id
      Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
      t = create_ticket
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
      ticket = create_ticket({ status: 2 }, group)
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
      ticket = create_ticket(status: 2, responder_id: ticket_restricted_agent.id)
      login_as(ticket_restricted_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)

      assert_match /#{ticket.description_html}/, response.body
    end

    def test_show_ticket_with_custom_date_format
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
      time_now = Time.zone.now
      t = create_ticket(custom_field: { ticket_field.name => time_now })
      put :show, controller_params({ version: 'private', id: t.display_id })
      ticket_date_format = Time.now.in_time_zone(@account.time_zone).strftime('%F')
      assert_response 200
      assert_equal ticket_date_format, JSON.parse(response.body)['custom_fields']['test_custom_date']
    end

    # Test when Internal agent have group tickets access.
    def test_ticket_access_for_group_restricted_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        group_restricted_agent = add_agent_to_group(group_id = @internal_group.id,
                                                    ticket_permission = 2, role_id = @account.roles.first.id)
        ticket = create_ticket({ status: @status.status_id }, nil, @internal_group)
        login_as(group_restricted_agent)
        get :show, controller_params(version: 'private', id: ticket.display_id)
        assert_match /#{ticket.description_html}/, response.body
      end
    end

    # Test ticket access by Internal agent when ticket has been assigned to him
    def test_ticket_access_by_Internal_restricted_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id }, nil, @internal_group)
        login_as(@internal_agent)
        get :show, controller_params(version: 'private', id: ticket.display_id)

        assert_match /#{ticket.description_html}/, response.body
      end
    end

    def test_ticket_assignment_to_internal_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({ status: 2, responder_id: @responding_agent.id }, group = @account.groups.find_by_id(2))
        # params = {
        #   :status => @status.status_id,
        #   :internal_group_id => @internal_group.id,
        #   :internal_agent_id => @internal_agent.id
        # }
        params = {
          status: @status.status_id,
          internal_group_id: @internal_group.id,
          internal_agent_id: @internal_agent.id
        }
        put :update, construct_params({ version: 'private', id: ticket.display_id }, params)

        login_as(@internal_agent)
        ticket.reload
        # get :show, controller_params(version: 'private', id: ticket.display_id)
        assert_match /#{ticket.description_html}/, response.body
      end
    end

    def test_tracker_create
      enable_adv_ticketing([:link_tickets]) do
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
      enable_adv_ticketing([:link_tickets]) do
        create_ticket
        ticket = Helpdesk::Ticket.last
        params_hash = ticket_params_hash.merge(related_ticket_ids: [ticket.display_id])
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('email', nil, append_msg: I18n.t('ticket.tracker_agent_error'))])
        assert !ticket.related_ticket?
      end
    end

    def test_tracker_create_without_feature
      create_ticket
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      ticket = Helpdesk::Ticket.last
      params_hash = ticket_params_hash.merge(email: agent.email, related_ticket_ids: [ticket.display_id])
      disable_adv_ticketing([:link_tickets])
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('related_ticket_ids', :require_feature_for_attribute, {
      code: :inaccessible_field, feature: :link_tickets, attribute: 'related_ticket_ids'
      })])
    end

    def test_child_create_without_feature
      parent_ticket = create_parent_ticket
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      disable_adv_ticketing([:parent_child_tickets, :field_service_management, :parent_child_infra])
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('parent_id', :require_feature_for_attribute, {
        code: :inaccessible_field, feature: :parent_child_infra, attribute: 'parent_id'
      })])
    end

    def test_child_create
      enable_adv_ticketing([:parent_child_tickets]) do
        Account.any_instance.stubs(:sla_management_v2).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
        create_parent_ticket
        parent_ticket = Account.current.tickets.last || create_parent_ticket
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 201
        latest_ticket = Account.current.tickets.last
        match_json(ticket_show_pattern(latest_ticket))
      end
    end

    def test_create_child_to_inaccessible_parent
      enable_adv_ticketing([:parent_child_tickets]) do
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(false)
        Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
        parent_ticket = create_parent_ticket
        User.any_instance.stubs(:has_ticket_permission?).returns(false)
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 403
        User.any_instance.unstub(:has_ticket_permission?)
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end
    end

    def test_create_child_to_parent_with_max_children
      enable_adv_ticketing([:parent_child_tickets]) do
        Helpdesk::Ticket.any_instance.stubs(:associates).returns((10..21).to_a)
        parent_ticket = create_parent_ticket
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', :exceeds_limit, limit: TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT)])
      end
    end

    def test_create_child_to_a_spam_parent
      enable_adv_ticketing([:parent_child_tickets]) do
        parent_ticket = create_parent_ticket
        parent_ticket.update_attributes(spam: true)
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', :invalid_parent)])
      end
    end

    def test_create_child_to_a_invalid_parent
      enable_adv_ticketing([:parent_child_tickets]) do
        parent_ticket = create_parent_ticket
        parent_ticket.update_attributes(association_type: 4) #Related
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', :invalid_parent)])
      end
    end

    def test_create_child_with_parent_attachments
      enable_adv_ticketing([:parent_child_tickets]) do
        parent = create_ticket_with_attachments
        params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: parent.attachments.map(&:id))
        stub_attachment_to_io do
          post :create, construct_params({ version: 'private' }, params)
        end
        child = Account.current.tickets.last
        match_json(ticket_show_pattern(child))
        assert child.attachments.count == parent.attachments.count
      end
    end

    def test_create_child_with_some_parent_attachments
      enable_adv_ticketing([:parent_child_tickets]) do
        parent = create_ticket_with_attachments(1, 5)
        params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: parent.attachments.map(&:id).first(1))
        stub_attachment_to_io do
          post :create, construct_params({ version: 'private' }, params)
        end
        child = Account.current.tickets.last
        match_json(ticket_show_pattern(child))
        assert child.attachments.count == 1
      end
    end

    def test_create_child_with_some_parent_attachments_some_new_attachments
      enable_adv_ticketing([:parent_child_tickets]) do
        parent = create_ticket_with_attachments(1, 5)
        parent_attachment_ids = parent.attachments.map(&:id).first(1)
        child_attachment_ids = []
        child_attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: parent_attachment_ids + child_attachment_ids)
        stub_attachment_to_io do
          post :create, construct_params({ version: 'private' }, params)
        end
        child = Account.current.tickets.last
        match_json(ticket_show_pattern(child))
        assert child.attachments.count == 2
      end
    end

    def test_create_child_with_no_parent_attachments_only_new_attachments
      enable_adv_ticketing([:parent_child_tickets]) do
        parent = create_ticket_with_attachments
        child_attachment_ids = []
        child_attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: child_attachment_ids)
        stub_attachment_to_io do
          post :create, construct_params({ version: 'private' }, params)
        end
        child = Account.current.tickets.last
        match_json(ticket_show_pattern(child))
        assert child.attachments.count == 1
      end
    end

    def test_merged_tkt_with_adv_features
      enable_adv_ticketing(%i(link_tickets parent_child_tickets)) do
        primary_tkt = create_ticket
        sec_tkt     = create_ticket
        Helpdesk::Ticket.any_instance.stubs(:parent_ticket).returns(primary_tkt.display_id)
        get :show, controller_params(version: 'private', id: sec_tkt.display_id)
        assert_response 200
        assert_equal false, JSON.parse(response.body)['can_be_associated']
        Helpdesk::Ticket.any_instance.unstub(:parent_ticket)
      end
    end

    def test_normal_tkt_with_adv_features
      enable_adv_ticketing(%i(link_tickets parent_child_tickets)) do
        tkt = create_ticket
        get :show, controller_params(version: 'private', id: tkt.display_id)
        assert_response 200
        assert_equal true, JSON.parse(response.body)['can_be_associated']
      end
    end

    def test_update_skill_attribute_without_feature
      Account.current.stubs(:skill_based_round_robin_enabled?).returns(false)
      user = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
      login_as(user)
      group = create_group(@account, ticket_assign_type: 2)
      ticket = create_ticket({}, group)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, skill_id: 1)
      assert_response 400
      match_json([bad_request_error_pattern(:skill_id, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'skill_id', feature: :skill_based_round_robin)])
      Account.current.unstub(:skill_based_round_robin_enabled?)
    end

    def test_update_skill_attribute_without_privilege
      Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
      user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      login_as(user)
      group = create_group(@account, ticket_assign_type: 2)
      ticket = create_ticket({}, group)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, skill_id: 1)
      assert_response 400
      match_json([bad_request_error_pattern(:skill_id, nil, code: :incompatible_field, append_msg: :no_edit_ticket_skill_privilege)])
      ticket.reload
      assert_equal nil, ticket.skill_id
      Account.current.unstub(:skill_based_round_robin_enabled?)
    end

    def test_update_skill_id_with_invalid_skill
      Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
      user = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
      login_as(user)
      group = create_group(@account, ticket_assign_type: 2)
      ticket = create_ticket({}, group)
      invalid_skill = @account.skills.length + 1
      put :update, construct_params({ version: 'private', id: ticket.display_id }, skill_id: invalid_skill)
      assert_response 400
      match_json([bad_request_error_pattern(:skill_id, nil, code: :invalid_value, append_msg: :invalid_skill_id)])
      ticket.reload
      assert_equal nil, ticket.skill_id
      Account.current.unstub(:skill_based_round_robin_enabled?)
    end

    def test_update_skill_attribute_with_privilege
      Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
      user = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
      login_as(user)
      group = create_group(@account, ticket_assign_type: 2)
      ticket = create_ticket({}, group)
      put :update, construct_params({ version: 'private', id: ticket.display_id }, skill_id: 1)
      assert_response 200
      ticket.reload
      assert_equal 1, ticket.skill_id
      Account.current.unstub(:skill_based_round_robin_enabled?)
    end

    def test_new_ticket_with_parent_child
      enable_adv_ticketing(%i(parent_child_tickets)) do
        Sidekiq::Testing.inline! do
          @account = Account.first.make_current
          @agent = get_admin
          @groups = []
          3.times { @groups << create_group(@account) }
          @current_user = User.current
          parent_template = create_tkt_template(name: Faker::Name.name,
                                                association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                                account_id: @account.id,
                                                accessible_attributes: {
                                                  access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                                })
          child_template = create_tkt_template(name: Faker::Name.name,
                                               subject: 'Test new ticket with parent and single child',
                                               association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                               account_id: @account.id,
                                               accessible_attributes: {
                                                 access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                               })
          child_template.build_parent_assn_attributes(parent_template.id)
          child_template.save

          params_hash = ticket_params_hash.merge(parent_template_id: parent_template.id, child_template_ids: [child_template.id])
          current_ticket_count = Helpdesk::Ticket.count
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 201
          updated_ticket_count = Helpdesk::Ticket.count
          assert_equal Helpdesk::Ticket.last.subject, 'Test new ticket with parent and single child'
          assert_equal (updated_ticket_count - current_ticket_count), 2
        end
      end
    end

    def test_new_ticket_with_parent_multiple_child
      enable_adv_ticketing(%i(parent_child_tickets)) do

          @account = Account.first.make_current
          @agent = get_admin
          @groups = []
          3.times { @groups << create_group(@account) }
          @current_user = User.current
          child_template_ids = []
          parent_template = create_tkt_template(name: Faker::Name.name,
                                                association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                                account_id: @account.id,
                                                accessible_attributes: {
                                                  access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                                })
          2.times do |i|
            child_template = create_tkt_template(name: Faker::Name.name,
                                                 subject: "Test child multiple #{i}",
                                                 association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                                 account_id: @account.id,
                                                 accessible_attributes: {
                                                   access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                                 })

            child_template.build_parent_assn_attributes(parent_template.id)
            child_template.save
            child_template_ids << child_template.id
          end

          params_hash = ticket_params_hash.merge(parent_template_id: parent_template.id, child_template_ids: child_template_ids)
          current_ticket_id = Helpdesk::Ticket.last.id
          Sidekiq::Testing.inline! do
            post :create, construct_params({ version: 'private' }, params_hash)
          end
          assert_response 201
          Helpdesk::Ticket.last(2).each do |ticket|
            assert ticket.subject.include?('Test child multiple')
          end
          last_ticket_id = Helpdesk::Ticket.last.id
          assert_equal current_ticket_id, (last_ticket_id - 3)
      end
    end

    def test_new_ticket_with_parent_child_with_invalid_child
      enable_adv_ticketing(%i(parent_child_tickets)) do
        Sidekiq::Testing.inline! do
          @account = Account.first.make_current
          @agent = get_admin
          @groups = []
          3.times { @groups << create_group(@account) }
          @current_user = User.current
          parent_template = create_tkt_template(name: Faker::Name.name,
                                                association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                                account_id: @account.id,
                                                accessible_attributes: {
                                                  access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                                })
          child_template = create_tkt_template(name: Faker::Name.name,
                                               subject: 'Test new ticket with parent and single child',
                                               association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                               account_id: @account.id,
                                               accessible_attributes: {
                                                 access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                               })
          child_template.build_parent_assn_attributes(parent_template.id)
          child_template.save

          params_hash = ticket_params_hash.merge(parent_template_id: parent_template.id, child_template_ids: [9999])
          current_ticket_id = Helpdesk::Ticket.last.id
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 400
          last_ticket_id = Helpdesk::Ticket.last.id
        end
      end
    end

    def test_new_ticket_with_parent_child_with_invalid_parent
      enable_adv_ticketing(%i(parent_child_tickets)) do
        Sidekiq::Testing.inline! do
          @account = Account.first.make_current
          @agent = get_admin
          @groups = []
          3.times { @groups << create_group(@account) }
          @current_user = User.current

          params_hash = ticket_params_hash.merge(parent_template_id: 99_999, child_template_ids: [9999])
          old_ticket_id = Helpdesk::Ticket.last.id
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 400
          match_json([bad_request_error_pattern('parent_template_id', :absent_in_db, resource: :parent_template, attribute: :parent_template_id)])
          last_ticket_id = Helpdesk::Ticket.last.id
          assert_equal old_ticket_id, last_ticket_id
        end
      end
    end

    def test_new_ticket_with_parent_child_with_inaccessible_parent
      enable_adv_ticketing(%i(parent_child_tickets)) do
        Sidekiq::Testing.inline! do
          @account = Account.first.make_current
          @agent = get_admin
          @groups = []
          3.times { @groups << create_group(@account) }
          existing_current_user = User.current
          agent = add_test_agent(@account)

          parent_template = create_tkt_template(name: Faker::Name.name,
                                                account_id: @account.id,
                                                association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                                accessible_attributes: { access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
                                                                         user_ids: [existing_current_user.id] })

          child_template = create_tkt_template(name: Faker::Name.name,
                                               subject: 'Test new ticket with parent and single child',
                                               association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                               account_id: @account.id,
                                               accessible_attributes: {
                                                 access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                               })
          child_template.build_parent_assn_attributes(parent_template.id)
          child_template.save

          login_as(agent)
          params_hash = ticket_params_hash.merge(parent_template_id: parent_template.id, child_template_ids: [child_template.id])
          old_ticket_id = Helpdesk::Ticket.last.id
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 400
          match_json([bad_request_error_pattern('parent_template_id', :absent_in_db, resource: :parent_template, attribute: :parent_template_id)])
          # match_json([bad_request_error_pattern('parent_template_id', :inaccessible_value, resource: :parent_template, attribute: :parent_template_id)])
          last_ticket_id = Helpdesk::Ticket.last.id
          login_as(existing_current_user)
        end
      end
    end

    def test_ticket_without_collab
      Account.current.revoke_feature(:collaboration)
      ticket = create_ticket
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
    ensure
      Account.current.add_feature(:collaboration)
    end

    def test_ticket_with_collab
      Account.any_instance.stubs(:collaboration_enabled?).returns(true)
      ticket = create_ticket
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      assert JSON.parse(response.body)['collaboration'].present?
      Account.any_instance.unstub(:collaboration_enabled?)
    end

    def test_ticket_with_freshconnect_freshid
      Account.any_instance.stubs(:freshconnect_enabled?).returns(true)
      Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
      User.any_instance.stubs(:freshid_authorization).returns(true)
      @ticket = create_ticket
      get :show, controller_params(version: 'private', id: @ticket.display_id)
      assert_response 200
      assert JSON.parse(response.body)['collaboration'].present?
      Account.any_instance.unstub(:freshconnect_enabled?)
      Account.any_instance.unstub(:freshid_integration_enabled?)
      User.any_instance.unstub(:freshid_authorization)
    end

    def test_show_collab_hash_without_logged_in_user
      user = User.current
      current_header = request.env['HTTP_AUTHORIZATION']
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      product_account_id = Random.rand(11).to_s
      domain = [Faker::Lorem.characters(10), 'freshconnect', 'com'].join('.')
      fc_account = ::Freshconnect::Account.new(
        account_id: Account.current.id,
        product_account_id: product_account_id,
        enabled: true,
        freshconnect_domain: domain
      )
      fc_account.save!
      token = generate_app_jwt_token(fc_account.product_account_id, Time.now.to_i, Time.now.to_i, 'freshconnect')
      auth = ['JWTAuth token=', token].join(' ')
      request.env['X-App-Header'] = auth
      ticket = create_ticket
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
    ensure
      request.env['HTTP_AUTHORIZATION'] = current_header
      request.env.delete('X-App-Header')
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      login_as(user)
      user.make_current
    end

    def test_suppression_list_alert
      ticket = create_ticket
      drop_email = Faker::Internet.email
      params_hash = { drop_email: drop_email }
      @controller.stubs(:private_email_failure?).returns(true)
      post :suppression_list_alert, controller_params({ version: 'private', id: ticket.display_id, drop_email: drop_email})
      assert_response 204
      ensure
        @controller.unstub(:private_email_failure?)
    end

    def test_suppression_list_alert_without_params
      ticket = create_ticket
      @controller.stubs(:private_api?).returns(true)
      @controller.stubs(:private_email_failure?).returns(true)
      post :suppression_list_alert, controller_params({ version: 'private', id: ticket.display_id })
      assert_response 400
      ensure
        @controller.unstub(:private_email_failure?)
        @controller.unstub(:private_api?)
    end

     def test_suppression_list_alert_with_invalid_ticket_id
      ticket = create_ticket
      @controller.stubs(:private_email_failure?).returns(true)
      post :suppression_list_alert, controller_params({ version: 'private', id: ticket.display_id+20 })
      assert_response 404
      ensure
        @controller.unstub(:private_email_failure?)
    end

    def test_failed_email_details_note
      @ticket = create_ticket
      @note = create_note(custom_note_params(@ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:email],true,0))
      stub_data = email_failures_note_activity
      @controller.stubs(:get_object_activities).returns(stub_data)
      @controller.stubs(:private_email_failure?).returns(true)
      params_hash = { note_id: @note.id }
      get :fetch_errored_email_details, controller_params({version: 'private', id: @ticket.display_id }, params_hash)
      match_json(failed_emails_note_pattern(stub_data))
      assert_response 200
      ensure
         @controller.unstub(:get_object_activities)
         @controller.unstub(:private_email_failure?)
    end

    def test_failed_email_details_ticket
      @ticket = create_ticket
      stub_data = email_failures_ticket_activity
      @controller.stubs(:get_object_activities).returns(stub_data)
      @controller.stubs(:private_email_failure?).returns(true)
      get :fetch_errored_email_details, controller_params({version: 'private', id: @ticket.display_id})
      match_json(failed_emails_ticket_pattern(stub_data))
      assert_response 200
      ensure
         @controller.unstub(:get_object_activities)
         @controller.unstub(:private_email_failure?)
    end

    def test_failed_email_details_with_invalid_ticket_id
      ticket = create_ticket
      get :fetch_errored_email_details, controller_params({version: 'private', id: ticket.display_id+20 })
      assert_response 404
    end

    def test_failed_email_details_with_invalid_data
      ticket = create_ticket
      @controller.stubs(:private_email_failure?).returns(true)
      @controller.stubs(:get_object_activities).returns(false)
      get :fetch_errored_email_details, controller_params({version: 'private', id: ticket.display_id })
      assert_response 400
      ensure
         @controller.unstub(:get_object_activities)
         @controller.unstub(:private_email_failure?)
    end

    def test_create_child_with_template
      enable_adv_ticketing([:parent_child_tickets]) do
        create_parent_child_template(2)
        child_template_ids = @child_templates.map(&:id)
        parent_ticket = create_ticket
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 204
        child_ticket = Account.current.tickets.last
        assert child_ticket.child_ticket?
        assert parent_ticket.reload.assoc_parent_ticket?
        assert_equal parent_ticket.child_tkts_count, 2
        assert_equal child_ticket.associated_prime_ticket('child'), parent_ticket
      end
    end

    def test_create_child_with_template_inherit_all
      enable_adv_ticketing([:parent_child_tickets]) do
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        @child_templates.last.template_data = { 'inherit_parent' => 'all' }
        @child_templates.last.save
        user = get_user_with_multiple_companies
        parent_ticket = create_ticket(requester_id: user.id)
        parent_ticket.company = user.companies.last
        parent_ticket.save
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 204
        child_ticket = Account.current.tickets.last
        TicketConstants::CHILD_DEFAULT_FD_MAPPING.each do |field|
          assert child_ticket.safe_send(field) == parent_ticket.safe_send(field)
        end
      end
    end

    def test_create_child_with_invalid_parent_template
      enable_adv_ticketing([:parent_child_tickets]) do
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        parent_ticket = Account.current.tickets.last
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @child_templates.first.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 400
        match_json([bad_request_error_pattern('parent_template_id', :invalid_parent_template)])
      end
    end

    def test_create_child_with_inaccessible_parent_template
      enable_adv_ticketing([:parent_child_tickets]) do
        agent = add_test_agent(@account)
        @groups = []
        @groups << create_group(@account)
        parent_template = create_tkt_template(name: Faker::Name.name,
                                        account_id: @account.id,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                        accessible_attributes: { access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users], user_ids: [agent.id] })
        child_template = create_tkt_template(name: Faker::Name.name,
                                        account_id: @account.id,
                                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                        accessible_attributes: { access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users], user_ids: [agent.id] })
        child_template.build_parent_assn_attributes(parent_template.id)
        child_template.save
        parent_ticket = Account.current.tickets.last
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: parent_template.id, child_template_ids: [child_template.id] }, false)
        end
        assert_response 400
        match_json([bad_request_error_pattern('parent_template_id', :inaccessible_parent_template)])
      end
    end

    def test_create_child_with_invalid_child_template
      enable_adv_ticketing([:parent_child_tickets]) do
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        parent_ticket = Account.current.tickets.last
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: [@parent_template.id] }, false)
        end
        assert_response 400
        match_json([bad_request_error_pattern('child_template_ids', :child_template_list, invalid_ids: @parent_template.id)])
      end
    end

    def test_create_child_with_template_to_invalid_parent
      enable_adv_ticketing([:parent_child_tickets]) do
        ticket = create_ticket
        ticket.update_attributes(association_type: 4) #Related
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', :invalid_parent)])
      end
    end

    def test_create_child_with_template_to_spam_parent
      enable_adv_ticketing([:parent_child_tickets]) do
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        parent_ticket = create_ticket
        parent_ticket.update_attributes(spam: true)
        parent_ticket.reload
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 404
      end
    end

    def test_create_child_with_template_to_inaccessible_parent
      enable_adv_ticketing([:parent_child_tickets]) do
        ticket_id = create_ticket(ticket_params_hash).display_id
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        User.any_instance.stubs(:has_read_ticket_permission?).returns(false)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: ticket_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        User.any_instance.unstub(:has_read_ticket_permission?)
        assert_response 403
      end
    end

    def test_create_child_with_template_to_parent_with_max_children
      enable_adv_ticketing([:parent_child_tickets]) do
        Helpdesk::Ticket.any_instance.stubs(:associates).returns((10..19).to_a)
        parent_ticket = create_parent_ticket
        create_parent_child_template(1)
        child_template_ids = @child_templates.map(&:id)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', :exceeds_limit, limit: TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT )])
      end
    end

    def test_create_child_with_template_exceeds_max_children
      enable_adv_ticketing([:parent_child_tickets]) do
        Helpdesk::Ticket.any_instance.stubs(:associates).returns((10..17).to_a)
        parent_ticket = create_parent_ticket
        create_parent_child_template(3)
        child_template_ids = @child_templates.map(&:id)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 400
        match_json([bad_request_error_pattern('parent_id', :exceeds_limit, limit: TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT )])
      end
    end

    def test_create_child_with_template_feature_disabled
      enable_adv_ticketing([:parent_child_tickets]) do
        create_parent_child_template(1)
      end
      disable_adv_ticketing([:parent_child_tickets])
      child_template_ids = @child_templates.map(&:id)
      Account.current.instance_variable_set('@pc', false) # Memoize is used. Hence setting it to false once the feature is disabled.
      parent_ticket = create_ticket
      Sidekiq::Testing.inline! do
        put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
      end
      assert_response 400
      match_json([bad_request_error_pattern('feature', :require_feature, feature: 'Parent Child Tickets')])
    end

    def test_create_child_with_template_read_access_agent
      enable_adv_ticketing([:parent_child_tickets]) do
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        create_parent_child_template(2)
        child_template_ids = @child_templates.map(&:id)
        parent_ticket = create_ticket
        read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        agent_group = create_agent_group_with_read_access(@account, read_access_agent)
        parent_ticket.group_id = agent_group.group_id
        parent_ticket.save!
        login_as(read_access_agent)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 204
        child_ticket = Account.current.tickets.last
        assert child_ticket.child_ticket?
        assert parent_ticket.reload.assoc_parent_ticket?
        assert_equal parent_ticket.child_tkts_count, 2
        assert_equal child_ticket.associated_prime_ticket('child'), parent_ticket
        log_out
        read_access_agent.destroy
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end
    end

    def test_create_child_with_template_read_access_agent_with_scope_off
      enable_adv_ticketing([:parent_child_tickets]) do
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(false)
        create_parent_child_template(2)
        child_template_ids = @child_templates.map(&:id)
        parent_ticket = create_ticket
        read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        agent_group = create_agent_group_with_read_access(@account, read_access_agent)
        parent_ticket.group_id = agent_group.group_id
        parent_ticket.save!
        login_as(read_access_agent)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: parent_ticket.display_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        assert_response 403
        log_out
        read_access_agent.destroy
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end
    end

    def test_compose_email_for_free_account_with_limit
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      change_subscription_state('free')
      @controller.stubs(:get_others_redis_key).returns(30)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 429
      error_info_hash = {count:30,details: 'in sprout plan'}
      match_json(request_error_pattern_with_info(:outbound_limit_exceeded,
                                                 error_info_hash,
                                                 error_info_hash))
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      @controller.unstub(:get_others_redis_key)
    end

    def test_compose_email_for_free_account_whitelisted
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      change_subscription_state('free')
      @controller.stubs(:ismember?).with(SPAM_WHITELISTED_ACCOUNTS, Account.current.id).returns(true)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 201
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      @controller.unstub(:ismember?)
    end

    def test_compose_email_for_trial_account_whitelisted
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      change_subscription_state('trial')
      @controller.stubs(:ismember?).with(SPAM_WHITELISTED_ACCOUNTS, Account.current.id).returns(true)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 201
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      @controller.unstub(:ismember?)
    end

    def test_compose_email_with_trial_limit
      email_config = create_email_config
      change_subscription_state('trial')
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      @controller.stubs(:get_others_redis_key)
          .with(OUTBOUND_EMAIL_COUNT_PER_DAY % { account_id: Account.current.id })
          .returns(6)
      @controller.stubs(:get_spam_account_id_threshold).returns(0)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 429
      error_info_hash = {count:5 ,details: 'during the trial period'}
      match_json(request_error_pattern_with_info(:outbound_limit_exceeded,
                                                 error_info_hash,
                                                 error_info_hash))
    ensure
      Account.any_instance.unstub(:compose_email_enabled)
      @controller.unstub(:get_others_redis_key)
      @controller.unstub(:get_spam_account_id_threshold)
    end

    def test_compose_email_with_unverified_account
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      Account.any_instance.stubs(:verified?).returns(false)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      Account.any_instance.unstub(:verified?)
    end

    def test_compose_email_with_max_emails_limit
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      @controller.stubs(:recipients_limit_exceeded?).returns(true)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 429
      match_json(request_error_pattern(:recipient_limit_exceeded))
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      @controller.unstub(:recipients_limit_exceeded?)
    end

    def test_create_with_email_limit
      @controller.stubs(:recipients_limit_exceeded?).returns(true)
      params = ticket_params_hash
      post :create, construct_params({ version: 'private' }, params)
      assert_response 429
      match_json(request_error_pattern(:recipient_limit_exceeded))
    ensure
      @controller.unstub(:recipients_limit_exceeded?)
    end

    def test_archive_show_ticket_redirection
      @account.make_current
      @account.enable_ticket_archiving(ARCHIVE_DAYS)
      @account.features.send(:archive_tickets).create
      create_archive_ticket_with_assoc(
        created_at: TICKET_UPDATED_DATE,
        updated_at: TICKET_UPDATED_DATE,
        create_association: true
      )
      stub_archive_assoc_for_show(@archive_association) do
        archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
        get :show, controller_params(version: 'private', id: archive_ticket.display_id)
        assert_response 301
        assert_match "/api/_/tickets/archived/#{archive_ticket.display_id}", response.body
      end
    ensure
      cleanup_archive_ticket(@archive_ticket)
    end

    def test_link_ticket_to_tracker
      enable_adv_ticketing([:link_tickets]) do
        tracker_id = create_tracker_ticket.display_id
        ticket_id = create_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
        assert_response 200
        ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
        assert ticket.related_ticket?
      end
    end

    def test_link_to_invalid_tracker
      enable_adv_ticketing([:link_tickets]) do
        tracker_id = create_ticket.display_id
        ticket_id = create_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
        pattern = ['tracker_id', :invalid_tracker]
        assert_link_failure(ticket_id, pattern)
      end
    end

    def test_link_to_spammed_tracker
      enable_adv_ticketing([:link_tickets]) do
        tracker = create_tracker_ticket
        tracker.update_attributes(spam: true)
        ticket_id = create_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker.display_id }, false)
        pattern = ['tracker_id', :invalid_tracker]
        assert_link_failure(ticket_id, pattern)
      end
    end

    def test_link_to_deleted_tracker
      enable_adv_ticketing([:link_tickets]) do
        tracker = create_tracker_ticket
        tracker.update_attributes(deleted: true)
        ticket_id = create_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker.display_id }, false)
        pattern = ['tracker_id', :invalid_tracker]
        assert_link_failure(ticket_id, pattern)
      end
    end

    def test_link_ticket_without_related_permission
      enable_adv_ticketing([:link_tickets]) do
        ticket_id = create_ticket.display_id
        tracker_id = create_tracker_ticket.display_id
        user_stub_ticket_permission
        put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
        assert_response 403
        ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
        assert !ticket.related_ticket?
        user_unstub_ticket_permission
      end
    end

    def test_link_ticket_without_tracker_permission
      enable_adv_ticketing([:link_tickets]) do
        ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
        ticket = create_ticket(responder_id: ticket_restricted_agent.id)
        tracker_ticket = create_tracker_ticket
        login_as(ticket_restricted_agent)
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker_ticket.display_id }, false)
        assert_response 200
        ticket = Helpdesk::Ticket.find_by_display_id(ticket.display_id)
        assert ticket.related_ticket?
      end
    end

    def test_link_a_deleted_ticket
      enable_adv_ticketing([:link_tickets]) do
        ticket = create_ticket
        ticket.update_attributes(deleted: true)
        ticket_id = ticket.display_id
        tracker_id = create_tracker_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
        assert_response 405
      end
    end

    def test_link_a_spammed_ticket
      enable_adv_ticketing([:link_tickets]) do
        ticket = create_ticket
        ticket.update_attributes(spam: true)
        tracker_id = create_tracker_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker_id }, false)
        assert_response 405
      end
    end

    def test_link_an_associated_ticket_to_tracker
      enable_adv_ticketing([:link_tickets]) do
        ticket = create_ticket
        ticket.update_attributes(association_type: 4)
        tracker_id = create_tracker_ticket.display_id
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: tracker_id }, false)
        assert_link_failure(nil, [:id, :unable_to_perform])
      end
    end

    def test_link_non_existant_ticket_to_tracker
      enable_adv_ticketing([:link_tickets]) do
        tracker_id = create_tracker_ticket.display_id
        put :update, construct_params({ version: 'private', id: tracker_id + 100, tracker_id: tracker_id }, false)
        assert_response 404
      end
    end

    def test_link_without_link_tickets_feature
      disable_adv_ticketing([:link_tickets]) if Account.current.launched?(:link_tickets)
      ticket = create_ticket
      ticket_id = ticket.display_id
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ version: 'private', id: ticket_id, tracker_id: tracker_id }, false)
      assert_response 400
      assert !ticket.related_ticket?
      match_json([bad_request_error_pattern('tracker_id', :require_feature_for_attribute, {
      code: :inaccessible_field, feature: :link_tickets, attribute: 'tracker_id'
      })])
    end

    def test_unlink_related_ticket_from_tracker
      enable_adv_ticketing([:link_tickets]) do
        create_linked_tickets
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([@tracker_id])
        put :update, construct_params({ version: 'private', id: @ticket_id, tracker_id: nil }, false)
        Helpdesk::Ticket.any_instance.unstub(:associates)
        assert_response 200
        ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
        assert !ticket.related_ticket?
      end
    end

    def test_unlink_non_related_ticket_from_tracker
      enable_adv_ticketing([:link_tickets]) do
        create_linked_tickets
        non_related_ticket_id = create_ticket.display_id
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([@tracker_id])
        put :update, construct_params({ version: 'private', id: non_related_ticket_id, tracker_id: nil }, false)
        Helpdesk::Ticket.any_instance.unstub(:associates)
        assert_response 400
        match_json([bad_request_error_pattern('id', :not_a_related_ticket)])
      end
    end

    def test_unlink_ticket_without_permission
      enable_adv_ticketing([:link_tickets]) do
        create_linked_tickets
        user_stub_ticket_permission
        put :update, construct_params({ version: 'private', id: @ticket_id, tracker_id: nil }, false)
        assert_unlink_failure(@ticket, 403)
        user_unstub_ticket_permission
      end
    end

    def test_unlink_non_existant_ticket_from_tracker
      enable_adv_ticketing([:link_tickets]) do
        create_linked_tickets
        Helpdesk::Ticket.where(display_id: @ticket_id).first.destroy
        put :update, construct_params({ version: 'private', id: @ticket_id, tracker_id: nil }, false)
        assert_response 404
      end
    end

    def test_unlink_without_link_tickets_feature
      enable_adv_ticketing([:link_tickets]) { create_linked_tickets }
      disable_adv_ticketing([:link_tickets]) if Account.current.launched?(:link_tickets)
      put :update, construct_params({ version: 'private', id: @ticket_id, tracker_id: nil }, false)
      assert_unlink_failure(@ticket, 400)
      match_json([bad_request_error_pattern('tracker_id', :require_feature_for_attribute, {
      code: :inaccessible_field, feature: :link_tickets, attribute: 'tracker_id'
      })])
    end

    def test_unlink_related_ticket_from_non_tracker
      enable_adv_ticketing([:link_tickets]) do
        create_linked_tickets
        non_tracker_id = create_ticket.display_id
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([non_tracker_id])
        put :update, construct_params({ version: 'private', id: @ticket_id, tracker_id: nil }, false)
        Helpdesk::Ticket.any_instance.unstub(:associates)
        assert_unlink_failure(@ticket, 400, ['tracker_id', :invalid_tracker])
      end
    end

    def test_unlink_without_both_tracker_and_related_permission
      enable_adv_ticketing([:link_tickets]) do
        ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
        ticket = create_ticket
        tracker_ticket = create_tracker_ticket
        link_to_tracker(ticket, tracker_ticket)
        login_as(ticket_restricted_agent)
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: nil }, false)
        assert_response 403
      end
    end

    def test_unlink_with_related_permission_and_without_tracker_permission
      enable_adv_ticketing([:link_tickets]) do
        ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
        ticket = create_ticket(responder_id: ticket_restricted_agent.id)
        tracker_ticket = create_tracker_ticket
        link_to_tracker(ticket, tracker_ticket)
        login_as(ticket_restricted_agent)
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: nil }, false)
        assert_response 200
        ticket = Helpdesk::Ticket.where(display_id: ticket.display_id).first
        assert !ticket.related_ticket?
      end
    end

    def test_unlink_without_related_ticket_permission
      enable_adv_ticketing([:link_tickets]) do
        ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
        ticket = create_ticket
        tracker_ticket = create_tracker_ticket(responder_id: ticket_restricted_agent.id)
        link_to_tracker(ticket, tracker_ticket)
        login_as(ticket_restricted_agent)
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: nil }, false)
        assert_response 200
        ticket = Helpdesk::Ticket.where(display_id: ticket.display_id).first
        assert !ticket.related_ticket?
      end
    end

    def test_unlink_with_other_params
      enable_adv_ticketing([:link_tickets]) do
        ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
        ticket = create_ticket
        tracker_ticket = create_tracker_ticket(responder_id: ticket_restricted_agent.id)
        link_to_tracker(ticket, tracker_ticket)
        login_as(ticket_restricted_agent)
        put :update, construct_params({ version: 'private', id: ticket.display_id, tracker_id: nil, status: 5 }, false)
        assert_response 403
      end
    end

    def test_compose_email_without_feature
      Account.any_instance.stubs(:compose_email_enabled?).returns(false)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {})
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'compose_email'.titleize))
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
    end

    def test_compose_email_with_invalid_params
      params = ticket_params_hash.merge(custom_fields: {}, product_id: 2, requester_id: 3, phone: 7, twitter_id: '67', facebook_id: 'ui')
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('product_id', :invalid_field),
                  bad_request_error_pattern('responder_id',  :invalid_field),
                  bad_request_error_pattern('requester_id',  :invalid_field),
                  bad_request_error_pattern('twitter_id',  :invalid_field),
                  bad_request_error_pattern('facebook_id',  :invalid_field),
                  bad_request_error_pattern('phone',  :invalid_field)])
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
    end

    def test_compose_email_without_source
      email_config = fetch_email_config
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      t = @account.tickets.last
      match_json(ticket_show_pattern(t))
      assert t.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]
      assert_response 201
    end

    def test_compose_with_source_as_outbound
      email_config = fetch_email_config
      params = ticket_params_hash.except(:product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      params[:source] = 10
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      t = @account.tickets.last
      match_json(ticket_show_pattern(t))
      assert t.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]
      assert_response 201
    end

    def test_compose_email_with_invalid_source
      email_config = fetch_email_config
      params = ticket_params_hash.except(:product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
    end

    def test_compose_email_as_read_access_agent
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      email_config = fetch_email_config
      read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      agent_group = create_agent_group_with_read_access(@account, read_access_agent)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, group_id: agent_group.group_id, email_config_id: email_config.id)
      login_as(read_access_agent)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.group_id, agent_group.group_id
      assert_equal nil, t.responder_id
      assert t.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]
      assert_response 201
    ensure
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end

    def test_compose_email_as_write_access_agent
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      email_config = fetch_email_config
      read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      agent_group = create_agent_group_with_write_access(@account, read_access_agent)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, group_id: agent_group.group_id, email_config_id: email_config.id)
      login_as(read_access_agent)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert_equal t.group_id, agent_group.group_id
      assert_equal t.responder_id, agent_group.user_id
      assert t.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]
      assert_response 201
    ensure
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end

    def test_compose_with_all_default_fields_required_valid
      default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
      default_non_required_fiels.map { |x| x.toggle!(:required) }
      default_non_required_fiels.select { |x| x.name == 'product' }.map { |x| x.toggle!(:required) }
      email_config = fetch_email_config
      params = { email: Faker::Internet.email, email_config_id: email_config.id, priority: 2, type: 'Feature Request', description: Faker::Lorem.characters(15), group_id: ticket_params_hash[:group_id], subject: Faker::Lorem.characters(15) }
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 201
    ensure
      default_non_required_fiels.map { |x| x.toggle!(:required) }
      default_non_required_fiels.select { |x| x.name == 'product' }.map { |x| x.toggle!(:required) }
    end

    def test_compose_with_attachment
      file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge('attachments' => [file, file2], status: '2', priority: '2', email_config_id: "#{fetch_email_config.id}")
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      response_params = params.except(:tags, :attachments)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      assert_response 201
      assert Helpdesk::Ticket.last.attachments.count == 2
    end

    def test_compose_email_attachment_content_type
      file = fixture_file_upload('/files/attachment.eml', 'message/rfc822')
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge('attachments' => [file], email_config_id: "#{fetch_email_config.id}")
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      ticket = Account.current.tickets.last
      attachment = ticket.all_attachments.first
      assert_equal 'message/rfc822', attachment.content_content_type
    end

    def test_compose_email_without_status
      email_config = fetch_email_config
      params = ticket_params_hash.except(:source, :status, :fr_due_by, :due_by, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      result = parse_response(@response.body)
      assert_equal 5, result['status']
      assert_response 201
    end

    def test_compose_email_without_responder_id
      email_config = fetch_email_config
      params = ticket_params_hash.except(:source, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
      result = parse_response(@response.body)
      assert_equal @agent.id, result['responder_id']
      assert_response 201
    end

    def test_compose_email_without_status_with_fr_due_by
      email_config = fetch_email_config
      params = ticket_params_hash.except(:source, :status, :due_by, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('fr_due_by',  :cannot_set_due_by_fields, code: :incompatible_field)])
    end

    def test_compose_email_without_status_with_due_by
      email_config = fetch_email_config
      params = ticket_params_hash.except(:source, :status, :fr_due_by, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('due_by',  :cannot_set_due_by_fields, code: :incompatible_field)])
    end

    def test_compose_email_without_mandatory_params
      params = ticket_params_hash.except(:source, :product_id, :responder_id, :email, :subject).merge(custom_fields: {})
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('email_config_id',  :field_validation_for_outbound, code: :missing_field),
                  bad_request_error_pattern('subject',  :field_validation_for_outbound, code: :missing_field),
                  bad_request_error_pattern('email',  :field_validation_for_outbound, code: :missing_field)])
    end

    def test_compose_email_with_invalid_email_config_id
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: 1234)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('email_config_id',  :absent_in_db, resource: :email_config, attribute: :email_config_id)])
    end

    def test_compose_email_with_deleted_email_config_id_on_update
      email_config = create_email_config
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
      params = ticket_params_hash.except(:source, :product_id, :responder_id, :email, :group_id).merge(custom_fields: {}, email_config_id: email_config.id, email: agent.email)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert t.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]
      assert_response 201
      @account.email_configs.find(email_config.id).destroy
      update_params = { status: 5, email: agent.email }
      params_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :email, :responder_id).merge(update_params)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
    end

    def test_compose_email_with_group_ticket_permission_valid
      Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
      User.any_instance.stubs(:can_view_all_tickets?).returns(false)
      User.any_instance.stubs(:group_ticket_permission).returns(true)
      email_config = create_email_config(group_id: ticket_params_hash[:group_id])
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
    ensure
      Account.any_instance.unstub(:restricted_compose_enabled?)
      User.any_instance.unstub(:can_view_all_tickets?)
      User.any_instance.unstub(:group_ticket_permission)
    end

    def test_compose_email_with_group_ticket_permission_invalid
      Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
      User.any_instance.stubs(:can_view_all_tickets?).returns(false)
      User.any_instance.stubs(:group_ticket_permission).returns(true)
      email_config = create_email_config(group_id: create_group(@account).id)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('email_config_id',  :inaccessible_value, resource: :email_config, attribute: :email_config_id)])
    ensure
      Account.any_instance.unstub(:restricted_compose_enabled?)
      User.any_instance.unstub(:can_view_all_tickets?)
      User.any_instance.unstub(:group_ticket_permission)
    end

    def test_compose_email_with_assign_ticket_permission_valid
      Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
      User.any_instance.stubs(:can_view_all_tickets?).returns(false)
      User.any_instance.stubs(:group_ticket_permission).returns(false)
      User.any_instance.stubs(:assigned_ticket_permission).returns(true)
      email_config = create_email_config
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      match_json(ticket_show_pattern(Helpdesk::Ticket.last))
    ensure
      Account.any_instance.unstub(:restricted_compose_enabled?)
      User.any_instance.unstub(:can_view_all_tickets?)
      User.any_instance.unstub(:group_ticket_permission)
      User.any_instance.unstub(:assigned_ticket_permission)
    end

    def test_compose_email_with_assign_ticket_permission_invalid
      Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
      User.any_instance.stubs(:can_view_all_tickets?).returns(false)
      User.any_instance.stubs(:group_ticket_permission).returns(false)
      User.any_instance.stubs(:assigned_ticket_permission).returns(true)
      email_config = create_email_config(group_id: create_group(@account).id)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('email_config_id',  :inaccessible_value, resource: :email_config, attribute: :email_config_id)])
    ensure
      Account.any_instance.unstub(:restricted_compose_enabled?)
      User.any_instance.unstub(:can_view_all_tickets?)
      User.any_instance.unstub(:group_ticket_permission)
      User.any_instance.unstub(:assigned_ticket_permission)
    end

    def test_update_properties_closure_status_with_product_required_for_closure_default_field_blank_negative
      Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
      t = create_ticket
      params_hash = { status: 5 }
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
    ensure
      Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
    end

    def test_update_properties_closure_status_with_product_required_for_closure_default_field_blank_positive
      Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
      t = create_ticket(@account)
      t.update_attributes(product: create_product)
      params_hash = { status: 5}
      put :update_properties, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 200
    ensure
      Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
    end

    def test_index_with_spam_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(true)
      t = create_ticket(spam: true)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(filter: 'spam')
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_new_and_my_open_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      t = create_ticket(status: 2)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(filter: 'new_and_my_open')
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_stats_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      t = create_ticket
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(include: 'stats')
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_description_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(true)
      t = create_ticket
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(include: 'description')
      assert_response 200
      param_object = OpenStruct.new(stats: true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object, [:description, :description_text]))
      match_json(pattern)
    ensure
      t.try(:destroy)
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_requester_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      user = add_new_user(@account)
      t = create_ticket(requester_id: user.id)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(requester_id: user.id)
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_filter_order_by_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      t_1 = create_ticket(status: 2, created_at: 10.days.ago)
      t_2 = create_ticket(status: 3, created_at: 11.days.ago)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t_1.id, t_2.id).to_json, status: 200)
      get :index, controller_params(order_by: 'status')
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t_2, param_object))
      pattern.push(index_ticket_pattern_with_associations(t_1, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_default_filter_order_type_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      t_1 = create_ticket(created_at: 10.days.ago)
      t_2 = create_ticket(created_at: 11.days.ago)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t_2.id, t_1.id).to_json, status: 200)
      get :index, controller_params(order_type: 'asc')
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t_1, param_object))
      pattern.push(index_ticket_pattern_with_associations(t_2, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_updated_since_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      t = create_ticket(updated_at: 2.days.from_now)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(updated_since: Time.zone.now.iso8601)
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_company_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      company = create_company
      user = add_new_user(@account)
      sidekiq_inline {
        user.company_id = company.id
        user.save!
      }
      t = create_ticket(requester_id: user.id)
      stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
      get :index, controller_params(company_id: "#{company.id}")
      assert_response 200
      param_object = OpenStruct.new(:stats => true)
      pattern = []
      pattern.push(index_ticket_pattern_with_associations(t, param_object))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:count_es_enabled?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_update_compose_email_with_subject_and_description
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      t = ticket
      t.update_attributes(source: 10, email_config_id: fetch_email_config.id)
      params_hash = update_ticket_params_hash.except(:email, :source).merge(subject: Faker::Lorem.paragraph, description: Faker::Lorem.paragraph)
      put :update, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('subject', :outbound_email_field_restriction, code: :incompatible_field),
                  bad_request_error_pattern('description', :outbound_email_field_restriction, code: :incompatible_field)])
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
    end

    def test_create_ticket_with_service_task_type_without_mandatory_custom_fields
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                          priority: 2, status: 2, type: SERVICE_TASK_TYPE}
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 400
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_ticket_when_fsm_enabled
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                          priority: 2, status: 2, type: 'Problem', responder_id: @agent.id }
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 201
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_ticket_with_custom_file_field_with_invalid_type
      custom_field = create_custom_field_dn('test_signature_file', 'file')
      Account.reset_current_account
      @account = Account.first
      params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                      priority: 2, status: 2, type: 'Problem', responder_id: @agent.id, custom_fields: { test_signature_file: '1234' } }
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      response_body = JSON.parse(response.body)
      match_json([bad_request_error_pattern('custom_fields.test_signature_file', :datatype_mismatch, expected_data_type: Integer, prepend_msg: :input_received, given_data_type: String)])
    ensure
      custom_field.destroy
    end

    def test_create_ticket_with_multiple_custom_file_and_text_fields
      flexifield_def = FlexifieldDef.find_by_account_id_and_module(@account.id, 'Ticket')
      file_field1_col_name = flexifield_def.first_available_column('file')
      file_custom_field1 = create_custom_field_dn('test_signature_file1', 'file', false, false, flexifield_name: file_field1_col_name)
      text_field1_col_name = flexifield_def.first_available_column('text')
      text_custom_field1 = create_custom_field_dn('test_text1', 'text', false, false, flexifield_name: text_field1_col_name)
      file_field2_col_name = flexifield_def.first_available_column('file')
      file_custom_field2 = create_custom_field_dn('test_signature_file2', 'file', false, false, flexifield_name: file_field2_col_name)
      text_field2_col_name = flexifield_def.first_available_column('text')
      text_custom_field2 = create_custom_field_dn('test_text2', 'text', false, false, flexifield_name: text_field2_col_name)
      attachment = create_file_ticket_field_attachment
      Account.reset_current_account
      @account = Account.first
      params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                      priority: 2, status: 2, type: 'Problem', responder_id: @agent.id,
                      custom_fields: { test_signature_file2: attachment.id, test_text1: 'my test work' } }
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      response_body = JSON.parse(response.body)
      assert_equal 'my test work', response_body['custom_fields']['test_text1']
      assert_equal attachment.id, response_body['custom_fields']['test_signature_file2']
    ensure
      text_custom_field2.destroy
      file_custom_field2.destroy
      text_custom_field1.destroy
      file_custom_field1.destroy
      Account.reset_current_account
    end

    def test_create_ticket_with_date_time_custom_field
      @account.ticket_fields.find_by_column_name("ff_date06").try(:destroy)
      create_custom_field('appointment_time', 'date_time', '06', true)
      Account.reset_current_account
      @account = Account.first
      params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                          priority: 2, status: 2, type: 'Problem', responder_id: @agent.id, custom_fields: { appointment_time: '2019-01-12T12:11:00'}}
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      response_body = JSON.parse(response.body)
      assert_equal response_body['custom_fields']['appointment_time'], '2019-01-12T12:11:00Z'
    ensure
      @account.ticket_fields.find_by_name("appointment_time_#{@account.id}").destroy
    end

    def test_create_ticket_with_date_time_custom_field_invalid
      @account.ticket_fields.find_by_column_name("ff_date06").try(:destroy)
      create_custom_field('appointment_time', 'date_time', true)
      params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10),
                      subject: Faker::Lorem.characters(10), priority: 2, status: 2, type: 'Problem',
                      responder_id: @agent.id, custom_fields: { appointment_time: 'Test'}}
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      response_body = JSON.parse(response.body)
      match_json([bad_request_error_pattern('custom_fields.appointment_time', :invalid_date, accepted: 'combined date and time ISO8601')])
    ensure
      @account.ticket_fields.find_by_name("appointment_time_#{@account.id}").destroy
    end

    def test_update_ticket_with_type_service_task_without_mandatory_custom_fields
      perform_fsm_operations
      Account.first.make_current
      ticket = create_ticket({type: SERVICE_TASK_TYPE})
      params_hash = { description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10) }
      put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
    ensure
      cleanup_fsm
    end

    def test_update_ticket_when_fsm_enabled
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          ticket = create_ticket
          params_hash = { description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10) }
          put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
          assert_response 200
        ensure
          cleanup_fsm
        end
      end
    end

    def test_other_custom_field_validations_when_fsm_enabled
      create_custom_field('email1', 'text',true)
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.first.make_current
          parent_ticket = create_ticket
          params_hash = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                          description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                          priority: 2, status: 2, type: SERVICE_TASK_TYPE, custom_fields: { cf_fsm_contact_name: 'test',
                          cf_fsm_service_location: 'test', cf_fsm_phone_number: 'test', email1: Faker::Internet.email }}
          post :create, construct_params({ version: 'private' }, params_hash )
          assert_response 201
        ensure
          @account.ticket_fields.find_by_name("email1_#{@account.id}").destroy
          cleanup_fsm
        end
      end
    end

    def test_update_fsm_appointment_start_time_with_value_less_than_end_time
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          time = Time.zone.now
          fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '123344', fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601)
          params = { custom_fields: { cf_fsm_appointment_start_time: (time + 2.hours).utc.iso8601, cf_fsm_appointment_end_time: (time + 1.hour).utc.iso8601 } }
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 400
          match_json([bad_request_error_pattern('custom_fields.cf_fsm_appointment_start_time', :invalid_date_time_range)])
        ensure
          fsm_ticket.destroy
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_update_properties_wtih_appointment_start_and_end_time
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          time = Time.zone.now
          fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '123344')
          params = { custom_fields: { cf_fsm_appointment_start_time: (time + 1.hours).utc.iso8601,
            cf_fsm_appointment_end_time: (time + 2.hour).utc.iso8601 } }
          put :update_properties, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
          response_body = JSON.parse(response.body)
          assert_not_nil response_body['custom_fields']['cf_fsm_appointment_start_time']
          assert_not_nil response_body['custom_fields']['cf_fsm_appointment_end_time']
        ensure
          fsm_ticket.destroy
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_update_properties_wtih_appointment_end_time_nil
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          time = Time.zone.now
          ticket_params = {fsm_contact_name: 'User', fsm_service_location: 'Location',
            fsm_phone_number: '123344', fsm_appointment_start_time: time.utc.iso8601,
            fsm_appointment_end_time: (time + 1.hour).utc.iso8601}
          fsm_ticket = create_service_task_ticket(ticket_params)
          params = { custom_fields: { cf_fsm_appointment_end_time: nil } }
          put :update_properties, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
          response_body = JSON.parse(response.body)
          assert_not_nil response_body['custom_fields']['cf_fsm_appointment_start_time']
          assert_nil response_body['custom_fields']['cf_fsm_appointment_end_time']
        ensure
          fsm_ticket.destroy
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_update_properties_wtih_fsm_phone_number
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '123344')
          params = { custom_fields: { cf_fsm_phone_number: '90908' } }
          put :update_properties, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 400
          match_json([bad_request_error_pattern('cf_fsm_phone_number', :invalid_field)])
        ensure
          fsm_ticket.destroy
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_order_by_without_enabling_fsm
      get :index, controller_params(version: 'private', updated_since: Time.zone.now.iso8601, order_by: 'appointment_start_time')
      assert_response 400
      match_json([bad_request_error_pattern('order_by', :not_included, list: sort_field_options.join(','), code: :invalid_value)])
    end

    def test_unassign_group_id_on_ticket_created_from_email
      group = create_group @account
      email_config = create_email_config(group_id: group.id)
      params_hash = { source: 1, email_config_id: email_config.id }
      ticket = create_ticket(params_hash, group)
      assert_equal group.id, ticket.group_id
      put :update, construct_params({ version: 'private', id: ticket.display_id }, { group_id: nil })
      assert_response 200
      assert_nil JSON.parse(response.body)['group_id']
    end

    def test_field_agent_update_appointments_with_field_agents_manage_appointments_setting_enabled
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          current_user = User.current
          enable_field_agents_can_manage_appointments_option
          Account.current.reload
          time = Time.zone.now
          field_agent = create_field_agent
          fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                                  fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601, responder_id: field_agent.id)
          params = { custom_fields: { cf_fsm_appointment_start_time: (time - 1.hour).utc.iso8601 } }
          login_as(field_agent)
          put :update_properties, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
        ensure
          log_out
          current_user.make_current
          cleanup_fsm
          Account.unstub(:current)
        end
      end
    end

    def test_field_agent_update_appointments_with_field_agents_manage_appointments_setting_disabled
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          current_user = User.current
          disable_field_agents_can_manage_appointments_option
          Account.current.reload
          time = Time.zone.now
          field_agent = create_field_agent
          fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                                  fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601, responder_id: field_agent.id)
          params = { custom_fields: { cf_fsm_appointment_start_time: (time - 1.hour).utc.iso8601 } }
          login_as(field_agent)
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          match_json(
              { "description" => "Validation failed",
                "errors" =>
                    [{ "field" => "custom_fields.cf_fsm_appointment_start_time",
                       "message" => "You are not authorized to perform this action.",
                       "code" => "access_denied" }] })
          assert_response 403
          put :update_properties, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          match_json(
              { "description" => "Validation failed",
                "errors" =>
                    [{ "field" => "custom_fields.cf_fsm_appointment_start_time",
                       "message" => "You are not authorized to perform this action.",
                       "code" => "access_denied" }] })
          assert_response 403
        ensure
          log_out
          current_user.make_current
          cleanup_fsm
          enable_field_agents_can_manage_appointments_option
          Account.unstub(:current)
        end
      end
    end

    def test_support_agent_update_appointments_with_field_agents_manage_appointments_setting_disabled
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
          Account.stubs(:current).returns(Account.first)
          disable_field_agents_can_manage_appointments_option
          Account.current.reload
          current_user = User.current
          support_agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id)
          support_agent.make_current
          time = Time.zone.now
          field_agent = create_field_agent
          fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                                  fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601, responder_id: field_agent.id)
          params = { custom_fields: { cf_fsm_appointment_start_time: (time - 1.hour).utc.iso8601 } }
          put :update, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
          put :update_properties, construct_params({ id: fsm_ticket.display_id, version: 'private' }, params)
          assert_response 200
        ensure
          log_out
          support_agent.try(:destroy)
          cleanup_fsm
          current_user.make_current
          enable_field_agents_can_manage_appointments_option
          Account.unstub(:current)
        end
      end
    end

    # Skip mandatory custom field validation on create ticket
    def test_create_ticket_with_enforce_mandatory_true_not_passing_custom_field
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'true' })
      )
      result = JSON.parse(created_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :missing_field,
          message: 'It should be a/an String'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_true_custom_field_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: '' }, query_params: { enforce_mandatory: 'true' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :invalid_value,
          message: 'It should not be blank as this is a mandatory field'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_true_passing_custom_field
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'test' }, query_params: { enforce_mandatory: 'true' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 201, result
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_false_not_passing_custom_field
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 201, result
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_false_custom_field_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: '' }, query_params: { enforce_mandatory: 'false' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :invalid_value,
          message: 'It should not be blank as this is a mandatory field'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_false_passing_custom_field
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'test' }, query_params: { enforce_mandatory: 'false' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 201, result
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_as_garbage_value
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'test' }, query_params: { enforce_mandatory: 'test' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'enforce_mandatory',
          code: :invalid_value,
          message: "It should be either 'true' or 'false'"
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    # Skip mandatory custom field validation on update ticket
    def test_update_ticket_without_required_custom_fields_with_enforce_mandatory_as_false
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        query_params: { enforce_mandatory: 'false' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 200, result
      assert_equal result['description'], 'testing'
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_without_required_custom_fields_with_enforce_mandatory_as_true
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        query_params: { enforce_mandatory: 'true' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :missing_field,
          message: 'It should be a/an String'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_without_required_custom_fields_default_enforce_mandatory_true
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing'
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :missing_field,
          message: 'It should be a/an String'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_empty_new_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: '' },
        query_params: { enforce_mandatory: 'true' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :invalid_value,
          message: 'It should not be blank as this is a mandatory field'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_empty_new_not_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: 'testing' },
        query_params: { enforce_mandatory: 'true' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 200, result
      assert_equal result['description'], 'testing'
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_not_empty_new_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: '' },
        query_params: { enforce_mandatory: 'true' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :invalid_value,
          message: 'It should not be blank as this is a mandatory field'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_not_empty_new_not_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: 'testing' },
        query_params: { enforce_mandatory: 'true' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 200, result
      assert_equal result['description'], 'testing'
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_empty_new_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: '' },
        query_params: { enforce_mandatory: 'false' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :invalid_value,
          message: 'It should not be blank as this is a mandatory field'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_empty_new_not_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: 'testing' },
        query_params: { enforce_mandatory: 'false' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 200, result
      assert_equal result['description'], 'testing'
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_not_empty_new_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: '' },
        query_params: { enforce_mandatory: 'false' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :invalid_value,
          message: 'It should not be blank as this is a mandatory field'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_false_not_passing_mandatory_dropdown_value
      cf = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
      cf.required = true
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
      )

      result = JSON.parse(created_ticket.body)
      assert_response 201, result
    ensure
      cf.required = false
    end

    def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_not_empty_new_not_empty
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']
      updated_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        description: 'testing',
        custom_fields: { cf_ticket: 'testing' },
        query_params: { enforce_mandatory: 'false' }
      )

      result = JSON.parse(updated_ticket.body)
      assert_response 200, result
      assert_equal result['description'], 'testing'
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_false_with_wrong_datatype
      cf = create_custom_field('cf_ticket', 'text', '05', true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params.merge(
          custom_fields: { cf_ticket: 123 },
          query_params: { enforce_mandatory: 'false' }
        )
      )

      result = JSON.parse(created_ticket.body)
      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :datatype_mismatch,
          message: 'Value set is of type Integer.It should be a/an String'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_ticket_with_enforce_mandatory_false_with_required_for_closure_custom_field
      cf = create_custom_field('cf_ticket', 'text', '05', false, true)
      Account.reset_current_account
      @account = Account.first
      created_ticket = post :create, construct_params(
        { version: 'private' },
        create_ticket_params
      )
      created_ticket_id = JSON.parse(created_ticket.body)['id']

      closed_ticket = put :update, construct_params(
        { version: 'private', id: created_ticket_id },
        status: 5,
        query_params: { enforce_mandatory: 'false' }
      )
      result = JSON.parse(closed_ticket.body)

      assert_response 400, result
      match_json(
        [{
          field: 'custom_fields.cf_ticket',
          code: :missing_field,
          message: 'It should be a/an String'
        }]
      )
    ensure
      @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
    end

    def test_create_service_task_enforce_mandatory_false_without_contact_name
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations

          created_ticket = post :create, construct_params(
            { version: 'private' },
            create_ticket_params
          )
          created_ticket_id = JSON.parse(created_ticket.body)['id']

          Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
          Account.reset_current_account

          created_service_task = post :create, construct_params(
            { version: 'private' },
            service_task_params.merge(
              parent_id: created_ticket_id,
              custom_fields: {
                cf_fsm_phone_number: Faker::Lorem.characters(10),
                cf_fsm_service_location: Faker::Lorem.characters(10)
              },
              query_params: { enforce_mandatory: 'false' }
            )
          )
          result = JSON.parse(created_service_task.body)
          assert_response 400, result
          match_json(
            [{
              field: 'cf_fsm_contact_name',
              code: :invalid_value,
              message: "can't be blank"
            }]
          )
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_service_task_enforce_mandatory_false_without_phone_number
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations

          created_ticket = post :create, construct_params(
            { version: 'private' },
            create_ticket_params
          )
          created_ticket_id = JSON.parse(created_ticket.body)['id']

          Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
          Account.reset_current_account
          created_service_task = post :create, construct_params(
            { version: 'private' },
            service_task_params.merge(
              parent_id: created_ticket_id,
              custom_fields: {
                cf_fsm_contact_name: Faker::Lorem.characters(10),
                cf_fsm_service_location: Faker::Lorem.characters(10)
              },
              query_params: { enforce_mandatory: 'false' }
            )
          )

          result = JSON.parse(created_service_task.body)
          assert_response 400, result
          match_json(
            [{
              field: 'cf_fsm_phone_number',
              code: :invalid_value,
              message: "can't be blank"
            }]
          )
        ensure
          cleanup_fsm
        end
      end
    end

    def test_create_service_task_enforce_mandatory_false_without_service_location
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations

          created_ticket = post :create, construct_params(
            { version: 'private' },
            create_ticket_params
          )
          created_ticket_id = JSON.parse(created_ticket.body)['id']

          Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
          Account.reset_current_account
          created_service_task = post :create, construct_params(
            { version: 'private' },
            service_task_params.merge(
              parent_id: created_ticket_id,
              custom_fields: {
                cf_fsm_contact_name: Faker::Lorem.characters(10),
                cf_fsm_phone_number: Faker::Lorem.characters(10)
              },
              query_params: { enforce_mandatory: 'false' }
            )
          )

          result = JSON.parse(created_service_task.body)
          assert_response 400, result
          match_json(
            [{
              field: 'cf_fsm_service_location',
              code: :invalid_value,
              message: "can't be blank"
            }]
          )
        ensure
          cleanup_fsm
        end
      end
    end

    def create_ticket_params
      {
        subject: Faker::Lorem.characters(10),
        description: Faker::Lorem.characters(10),
        status: 2,
        priority: 1,
        email: Faker::Internet.email
      }
    end

    def service_task_params
      {
        subject: Faker::Lorem.characters(10),
        description: Faker::Lorem.characters(10),
        status: 2,
        type: 'Service Task',
        priority: 1
      }
    end

    def test_every_response_status_with_note
      @account.stubs(:next_response_sla_enabled?).returns(true)
      t = create_ticket
      # when agent responded on time
      t.nr_due_by = Time.zone.now.utc + 30.minutes
      t.save
      assert_equal t.nr_violated?, nil
      assert_equal t.every_response_status, ''
      note1 = create_note(source: 2, ticket_id: t.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph)
      t.reload
      assert_equal t.nr_violated?, false
      assert_equal t.every_response_status, 'Within SLA'
      # when agent has responded after the expected time
      t.nr_due_by = Time.zone.now.utc
      t.save
      note2 = create_note(source: 2, ticket_id: t.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph)
      t.reload
      assert_equal t.nr_violated?, true
      assert_equal t.every_response_status, 'SLA Violated'
    ensure
      t.destroy
      @account.unstub(:next_response_sla_enabled?)
    end

    def test_every_response_status_without_note
      @account.stubs(:next_response_sla_enabled?).returns(true)
      t = create_ticket
      t.nr_due_by = Time.zone.now.utc
      t.save
      # when agent has not responded on time
      t.nr_escalated = true
      t.save
      t.reload
      assert_equal t.nr_violated?, nil
      assert_equal t.every_response_status, 'SLA Violated'
    ensure
      t.destroy
      @account.unstub(:next_response_sla_enabled?)
    end

    def test_jwe_token_generation_for_get_request
      current_account_id = Account.current.id
      acc = Account.find(current_account_id).make_current
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      add_privilege(User.current, :view_secure_field)
      ticket = create_ticket
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      params = { id: ticket.display_id, version: 'private' }
      get :vault_token, controller_params(params)
      token = response.api_meta[:vault_token]
      key = ApiTicketsTestHelper::PRIVATE_KEY_STRING
      payload = JSON.parse(JWE.decrypt(token, key))
      assert_equal payload['action'], 1
      assert_equal payload['otype'], 'ticket'
      assert_equal payload['oid'], ticket.id
      assert_equal payload['user_id'], User.current.id
      assert_equal payload['uuid'].to_s, uuid
      assert_equal payload['iss'], 'fd/poduseast'
      assert_equal payload['scope'], ['custom_card_no_test']
      assert_equal payload['exp'], payload['iat'] + PciConstants::EXPIRY_DURATION.to_i
      assert_equal payload['accid'], current_account_id
      assert_equal payload['portal'], 1
      assert_response 200
    ensure
      ticket.destroy
      request.unstub(:uuid)
      acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      remove_privilege(User.current, :view_secure_field)
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_jwe_token_generation_for_get_request_without_privilege
      current_account_id = Account.current.id
      acc = Account.find(current_account_id).make_current
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      ticket = create_ticket
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      params = { id: ticket.display_id, version: 'private' }
      get :vault_token, controller_params(params)
      assert_response 403
    ensure
      ticket.destroy
      request.unstub(:uuid)
      acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_jwe_token_generation_for_put_request_with_prefix
      current_account_id = Account.current.id
      acc = Account.find(current_account_id).make_current
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      add_privilege(User.current, :view_secure_field)
      add_privilege(User.current, :edit_secure_field)
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      params = ticket_params_hash
      ticket = create_ticket(params)
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      update_params = { custom_fields: { '_custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      token = response.api_meta[:vault_token]
      key = ApiTicketsTestHelper::PRIVATE_KEY_STRING
      payload = JSON.parse(JWE.decrypt(token, key))
      assert_equal payload['action'], 2
      assert_equal payload['otype'], 'ticket'
      assert_equal payload['oid'], ticket.id
      assert_equal payload['user_id'], User.current.id
      assert_equal payload['uuid'].to_s, uuid
      assert_equal payload['iss'], 'fd/poduseast'
      assert_equal payload['scope'], ['custom_card_no_test']
      assert_equal payload['exp'], payload['iat'] + PciConstants::EXPIRY_DURATION.to_i
      assert_equal payload['accid'], current_account_id
      assert_equal payload['portal'], 1
      assert_response 200
    ensure
      ticket.destroy
      request.unstub(:uuid)
      acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      remove_privilege(User.current, :view_secure_field)
      remove_privilege(User.current, :edit_secure_field)
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_jwe_token_generation_for_put_request_without_privilege
      current_account_id = Account.current.id
      acc = Account.find(current_account_id).make_current
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      params = ticket_params_hash
      ticket = create_ticket(params)
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      update_params = { custom_fields: { '_custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 400
    ensure
      ticket.destroy
      request.unstub(:uuid)
      acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_jwe_token_generation_for_put_request_without_prefix
      acc = Account.find(Account.current.id).make_current
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      add_privilege(User.current, :view_secure_field)
      add_privilege(User.current, :edit_secure_field)
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      params = ticket_params_hash
      ticket = create_ticket(params)
      update_params = { custom_fields: { 'custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 400
    ensure
      ticket.destroy
      acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      remove_privilege(User.current, :view_secure_field)
      remove_privilege(User.current, :edit_secure_field)
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_jwe_token_generation_for_put_request_without_secure_field
      acc = Account.find(Account.current.id).make_current
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      params = ticket_params_hash
      ticket = create_ticket(params)
      update_params = { custom_fields: { test_custom_text: 'sample text' }}
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_equal response.api_meta, nil
      assert_response 200
    ensure
      ticket.destroy
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_close_ticket_with_secure_text_field
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      ::Tickets::VaultDataCleanupWorker.jobs.clear
      Account.first.make_current
      name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
      secure_text_field = create_custom_field_dn(name, 'secure_text')
      ticket = create_ticket
      assert_not_nil ticket
      update_params = { status: Helpdesk::Ticketfields::TicketStatus::CLOSED }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
      assert_equal 1, ::Tickets::VaultDataCleanupWorker.jobs.size
      job = ::Tickets::VaultDataCleanupWorker.jobs.first.deep_symbolize_keys
      assert_equal [ticket.id], job[:args][0][:object_ids]
      assert_equal 'close', job[:args][0][:action]
    ensure
      secure_text_field.destroy
      Account.reset_current_account
      ::Tickets::VaultDataCleanupWorker.jobs.clear
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_show_with_old_secure_text_field_data
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      Account.first.make_current
      add_privilege(User.current, :view_secure_field)
      add_privilege(User.current, :edit_secure_field)
      name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
      secure_text_field = create_custom_field_dn(name, 'secure_text')
      secure_text_field_name = "_#{name}"
      ticket = create_ticket
      assert_not_nil ticket
      update_params = { custom_fields: { secure_text_field_name => Faker::Number.number(5) } }
      put :update, construct_params({ id: ticket.display_id, version: 'private' }, update_params)
      assert_response 200
      secure_text_field.destroy
      name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
      new_secure_text_field = create_custom_field_dn(name, 'secure_text')
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      response_body = JSON.parse(response.body)
      assert_nil response_body['custom_fields'][name]
    ensure
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
      new_secure_text_field.destroy
      ticket.destroy
      ::Tickets::VaultDataCleanupWorker.jobs.clear
      remove_privilege(User.current, :view_secure_field)
      remove_privilege(User.current, :edit_secure_field)
    end

    def test_update_properties_with_scope_read
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      dt = 10.days.from_now.utc.iso8601
      tags = Faker::Lorem.words(3).uniq
      login_as(agent)
      params_hash = { due_by: dt, responder_id: agent.id, status: 2, priority: 4, group_id: group.id, tags: tags }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
    ensure
      group.destroy if group.present?
    end

    def test_update_properties_assigned_to_ticket_with_scope_read
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({responder_id: agent.id}, group)
      login_as(agent)
      params_hash = { priority: 4 }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
    ensure
      group.destroy if group.present?
    end

    def test_destroy_ticket_with_scope_read
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      login_as(agent)
      delete :destroy, construct_params(id: ticket.display_id)
      assert_response 403
    ensure
      group.destroy if group.present?
    end

    def test_index_ticket_with_scope_read
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      tickets_count1 = JSON.parse(@response.body).count
      ticket = create_ticket({}, group)
      login_as(agent)
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      tickets_count2 = JSON.parse(@response.body).count
      assert_equal tickets_count1, tickets_count2
    ensure
      group.destroy if group.present?
      agent.destroy if agent.present?
    end

    def test_index_with_only_count_for_read_access_agent
      @account.stubs(:count_es_enabled?).returns(false)
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      login_as(agent)
      get :index, controller_params(version: 'private', filter: 'all_tickets', only: 'count')
      tickets_count1 = @response.api_meta[:count] 
      assert_equal tickets_count1, 1
    ensure
      group.destroy if group.present?
      agent.destroy if agent.present?
      @account.unstub(:count_es_enabled?)
    end
    
    def test_latest_note_ticket_with_public_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      ticket = create_ticket({}, group)
      note = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:note]))
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    ensure
      group.destroy if group.present?
      agent.destroy if agent.present?
    end

    def test_latest_note_ticket_with_private_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      ticket = create_ticket({}, group)
      note = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:note], true))
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      get :latest_note, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    ensure
      group.destroy if group.present?
      agent.destroy if agent.present?
    end
  end
end

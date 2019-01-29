require 'webmock/minitest'
require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb', 'ticket_template_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb', 'shared_ownership_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['tickets_test_helper.rb', 'bot_response_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module Ember
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include ScenarioAutomationsTestHelper
    include AttachmentsTestHelper
    include GroupHelper
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
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant
    ARCHIVE_DAYS = 120
    TICKET_UPDATED_DATE = 150.days.ago

    BULK_ATTACHMENT_CREATE_COUNT = 2

    def setup
      super
      @private_api = true
      Sidekiq::Worker.clear_all
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.current.features.es_v2_writes.destroy
      Account.current.reload
      @account.sections.map(&:destroy)
      tickets_controller_before_all(@@before_all_run)
      @@before_all_run=true unless @@before_all_run
    end

    @@before_all_run=false

    def wrap_cname(params)
      { ticket: params }
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

    def test_index_with_invalid_filter_id
      get :index, controller_params(version: 'private', filter: @account.ticket_filters.last.id + 10)
      assert_response 400
      match_json([bad_request_error_pattern(:filter, :absent_in_db, resource: :ticket_filter, attribute: :filter)])
    end

    def test_index_with_all_tickets_filter
      # Private API should filter all tickets with last 30 days created_at limit
      test_ticket = create_ticket(created_at: 2.months.ago)
      get :index, controller_params(version: 'private', filter: 'all_tickets')
      assert_response 200
    end

    def test_index_with_invalid_filter_names
      Account.current.stubs(:freshconnect_enabled?).returns(true)
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
      get :index, controller_params(version: 'private', only: 'count')
      assert_response 200
      assert response.api_meta[:count] == @account.tickets.where(['spam = false AND deleted = false AND created_at > ?', 30.days.ago]).count
      match_json([])
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
      invalid_attachment_size = @account.attachment_limit + 10
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_size.megabytes)
      post :create, construct_params({ version: 'private' }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_size} MB")])
      assert_response 400
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

    def test_create_service_task_ticket_failure
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations
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

    def test_create_service_task_ticket_with_invalid_field_agent_failure
      enable_adv_ticketing([:field_service_management]) do
       begin
         perform_fsm_operations
         parent_ticket = create_ticket
         params = { responder_id: @agent.id, parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                   custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
         post :create, construct_params({version: 'private'}, params)
         match_json([bad_request_error_pattern('responder_id', :only_field_agent_allowed, :code => :invalid_value)])
         assert_response 400
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

    def test_update_non_service_task_ticket_to_service_task_failure 
      enable_adv_ticketing([:field_service_management]) do
        begin
          perform_fsm_operations      
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
      @account.launch(:pricing_plan_change_2019)
      @account.revoke_feature :scenario_automation
      @account.features.scenario_automations.destroy if @account.features.scenario_automations?
      put :execute_scenario, construct_params({ version: 'private', id: ticket.display_id }, scenario_id: scn_auto.id)
      assert_response 403
      @account.rollback(:pricing_plan_change_2019)
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
      @bot = @account.main_portal.bot || create_test_email_bot({email_channel: true})
      @account.reload
      ticket = create_ticket({source: 1})
      ::Bot::Emailbot::SendBotEmail.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 1, ::Bot::Emailbot::SendBotEmail.jobs.size 
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
    end

    def test_create_from_email_without_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(false)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      ticket = create_ticket({source: 1})
      ::Bot::Emailbot::SendBotEmail.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute 
      assert_equal 0, ::Bot::Emailbot::SendBotEmail.jobs.size 
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
    end

    def test_create_from_email_without_email_bot_channel
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(false)
      ticket = create_ticket({source: 1})
      ::Bot::Emailbot::SendBotEmail.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute   
      assert_equal 0, ::Bot::Emailbot::SendBotEmail.jobs.size 
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
    end

    def test_create_from_other_source_with_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      ticket = create_ticket
      ::Bot::Emailbot::SendBotEmail.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Bot::Emailbot::SendBotEmail.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
    end

    def test_spam_ticket_with_bot_configuration
      Account.any_instance.stubs(:support_bot_configured?).returns(true)
      Account.any_instance.stubs(:bot_email_channel_enabled?).returns(true)
      ticket = create_ticket({spam: true})
      ::Bot::Emailbot::SendBotEmail.jobs.clear
      args = {'ticket_id' => ticket.id, 'user_id' => ticket.requester_id, 'is_webhook' => ticket.freshdesk_webhook?, 'sla_args' => {'sla_on_background' => ticket.sla_on_background, 'sla_state_attributes' => ticket.sla_state_attributes, 'sla_calculation_time' => ticket.sla_calculation_time.to_i}}
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
      assert_equal 0, ::Bot::Emailbot::SendBotEmail.jobs.size
      Account.any_instance.unstub(:support_bot_configured?)
      Account.any_instance.unstub(:bot_email_channel_enabled?)
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

    def test_execute_scenario_with_invalid_ticket_type
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      Helpdesk::Ticket.any_instance.stubs(:service_task?).returns(true)
      put :execute_scenario, construct_params({ version: 'private', id: ticket_id }, scenario_id: scenario_id)
      assert_response 400
      match_json([bad_request_error_pattern('id', :fsm_ticket_scenario_failure)])
    ensure
      Helpdesk::Ticket.any_instance.unstub(:service_task?)
      Account.any_instance.unstub(:field_service_management_enabled?)
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

    def test_execute_scenario_failure_with_closure_action
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
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
    end

    def test_execute_scenario_for_nested_dropdown_with_closure_action_without_dropdown_value_present
      scenario = create_scn_automation_rule(scenario_automation_params.merge(close_action_params))
      ticket_field1 = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field2 = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, true) }
      t = create_ticket({custom_field: { ticket_field1.name => 'Sample Text', ticket_field2.name => 'USA' }})
      put :execute_scenario, construct_params({ version: 'private', id: t.display_id }, scenario_id: scenario.id)
      assert_response 400
    ensure
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
    end

    def test_execute_scenario_success_with_closure_action
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
      Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
      [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
    end

    def test_execute_scenario_with_closure_of_parent_ticket_failure
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
      Helpdesk::Ticket.any_instance.unstub(:child_ticket?)
      Helpdesk::Ticket.any_instance.unstub(:associates)
      Helpdesk::Ticket.any_instance.unstub(:association_type)
    end

    def test_execute_scenario_with_closure_of_parent_ticket_success
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
      Helpdesk::Ticket.any_instance.unstub(:child_ticket?)
      Helpdesk::Ticket.any_instance.unstub(:associates)
      Helpdesk::Ticket.any_instance.unstub(:association_type)
    end

    def test_execute_scenario
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
      ticket.remove_instance_variable('@ticket_body_content')
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal attachment_ids, ticket.attachment_ids
    end

    def test_update_properties_with_subject_description_requester_source_phone
      ticket = create_ticket(source: TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone])
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
      ticket.remove_instance_variable('@ticket_body_content')
      assert_equal subject, ticket.subject
      assert_equal description, ticket.description
      assert_equal requester_id, ticket.requester_id
      assert_equal sender_email, ticket.sender_email
      assert_equal attachment_ids, ticket.attachment_ids      
    end

    def test_update_properties_with_subject_description_requester_source_email
      ticket = create_ticket(source: TicketConstants::SOURCE_KEYS_BY_TOKEN[:email])
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
      ticket.remove_instance_variable('@ticket_body_content')
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
      ticket.remove_instance_variable('@ticket_body_content')
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
      ticket.remove_instance_variable('@ticket_body_content')
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
      get :show, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(ticket_show_pattern(t, nil, true))
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
      get :show, controller_params(version: 'private', id: ticket.display_id, include: 'requester,company')
      assert_response 200
      res = JSON.parse(response.body)
      ticket_date_format = Time.now.in_time_zone(@account.time_zone).strftime('%F')
      contact_field.destroy
      company_field.destroy
      assert_equal ticket_date_format, res['requester']['custom_fields']['requester_date']
      assert_equal ticket_date_format, res['company']['custom_fields']['company_date']
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

    def test_export_csv_with_limit_reach
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
      params_hash = { ticket_fields: {"display_id": "id" }, contact_fields: {"name":"Requester Name","mobile":"Mobile Phone" },
                      company_fields:{"name":"Company Name"},
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 429
      DataExport.where(:id => export_ids).destroy_all

    end

    def test_export_csv_without_privilege
      User.any_instance.stubs(:privilege?).with(:export_tickets).returns(false)
      params_hash = { ticket_fields: {"display_id": "id" }, contact_fields: {"name":"Requester Name","mobile":"Mobile Phone" },
                      company_fields:{"name":"Company Name"},
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }] }

      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 403
      User.any_instance.unstub(:privilege?)
    end

    def test_export_csv_with_archive_export_limit_reached
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
      params_hash = { ticket_fields: {"display_id": "id" }, contact_fields: {"name":"Requester Name","mobile":"Mobile Phone" },
                      company_fields:{"name":"Company Name"},
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }] }

      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      DataExport.where(:id => export_ids).destroy_all
    end

    def test_export_csv_with_limit_reach_per_user
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
      params_hash = { ticket_fields: {"display_id": "id" }, contact_fields: {"name":"Requester Name","mobile":"Mobile Phone" },
                      company_fields:{"name":"Company Name"},
                      format: 'csv', date_filter: '30',
                      ticket_state_filter: 'resolved_at', start_date: 6.days.ago.iso8601, end_date: Time.zone.now.iso8601,
                      query_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => %w(2 5) }] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      DataExport.where(:id => export_ids).destroy_all
    end

    def test_export_inline_sidekiq_csv_with_no_tickets
      WebMock.allow_net_connect!
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
      WebMock.disable_net_connect!
    end

    def test_export_inline_sidekiq_csv_with_privilege
      WebMock.allow_net_connect!
      @account.launch(:ticket_contact_export)
      2.times do
        create_ticket
      end
      initial_count = ticket_data_export(DataExport::EXPORT_TYPE[:ticket]).count
      params_hash = ticket_export_param
      Sidekiq::Testing.inline! do
        post :export_csv, construct_params({ version: 'private' }, params_hash)
      end
      current_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:ticket])
      assert_equal initial_count, current_data_exports.length - 1
      assert_equal current_data_exports.last.status, DataExport::EXPORT_STATUS[:completed]
      assert current_data_exports.last.attachment.content_file_name.ends_with?('.csv')
      @account.rollback(:ticket_contact_export)
      WebMock.disable_net_connect!
    end

    def test_export_inline_sidekiq_xls_with_privilege
      WebMock.allow_net_connect!
      @account.launch(:ticket_contact_export)
      2.times do
        create_ticket
      end
      initial_count = ticket_data_export(DataExport::EXPORT_TYPE[:ticket]).count
      params_hash = ticket_export_param.merge(format: 'xls')
      Sidekiq::Testing.inline! do
        post :export_csv, construct_params({ version: 'private' }, params_hash)
      end
      current_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:ticket])
      assert_equal initial_count, current_data_exports.length - 1
      assert_equal current_data_exports.last.status, DataExport::EXPORT_STATUS[:completed]
      assert current_data_exports.last.attachment.content_file_name.ends_with?('.xls')
      @account.rollback(:ticket_contact_export)
      WebMock.disable_net_connect!
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
        Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
        parent_ticket = create_parent_ticket
        User.any_instance.stubs(:has_ticket_permission?).returns(false)
        params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
        post :create, construct_params({ version: 'private' }, params_hash)
        assert_response 403
        User.any_instance.unstub(:has_ticket_permission?)
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
          current_ticket_id = Helpdesk::Ticket.last.id
          post :create, construct_params({ version: 'private' }, params_hash)
          assert_response 201
          last_ticket_id = Helpdesk::Ticket.last.id
          assert_equal Helpdesk::Ticket.last.subject, 'Test new ticket with parent and single child'
          assert_equal current_ticket_id, (last_ticket_id - 2)
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
      @note = create_note(custom_note_params(@ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:email],true,0))
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
        User.any_instance.stubs(:has_ticket_permission?).returns(false)
        Sidekiq::Testing.inline! do
          put :create_child_with_template, construct_params({ version: 'private', id: ticket_id, parent_template_id: @parent_template.id, child_template_ids: child_template_ids }, false)
        end
        User.any_instance.unstub(:has_ticket_permission?)
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

    def test_compose_email_for_free_account_with_limit
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      change_subscription_state("free")
      @controller.stubs(:trial_outbound_limit_exceeded?).returns(true)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 429
      match_json(request_error_pattern(:outbound_limit_exceeded))
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      @controller.unstub(:trial_outbound_limit_exceeded?)
    end

    def test_compose_email_with_trial_limit
      email_config = create_email_config
      Account.any_instance.stubs(:compose_email_enabled?).returns(true)
      @controller.stubs(:trial_outbound_limit_exceeded?).returns(true)
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(email_config_id: email_config.id)
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      assert_response 429
      match_json(request_error_pattern(:outbound_limit_exceeded))
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
      @controller.unstub(:trial_outbound_limit_exceeded?)
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
      match_json([bad_request_error_pattern('source',  :invalid_field),
                  bad_request_error_pattern('product_id',  :invalid_field),
                  bad_request_error_pattern('responder_id',  :invalid_field),
                  bad_request_error_pattern('requester_id',  :invalid_field),
                  bad_request_error_pattern('twitter_id',  :invalid_field),
                  bad_request_error_pattern('facebook_id',  :invalid_field),
                  bad_request_error_pattern('phone',  :invalid_field)])
    ensure
      Account.any_instance.unstub(:compose_email_enabled?)
    end

    def test_compose_email
      email_config = fetch_email_config
      params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
      CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
      end
      post :create, construct_params({ version: 'private', _action: 'compose_email' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_show_pattern(t))
      assert t.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]
      assert_response 201
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
      assert t.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:outbound_email]
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
      Account.any_instance.stubs(:dashboard_new_alias?).returns(true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
      Account.any_instance.unstub(:es_tickets_enabled?)
    end

    def test_index_with_new_and_my_open_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
    end

    def test_index_with_stats_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
    end

    def test_index_with_requester_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
    end

    def test_index_with_filter_order_by_with_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
    end

    def test_index_with_default_filter_order_type_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
    end

    def test_index_updated_since_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
    end

    def test_index_with_company_count_es_enabled
      Account.any_instance.stubs(:count_es_enabled?).returns(:true)
      Account.any_instance.stubs(:es_tickets_enabled?).returns(:true)
      Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
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
      Account.any_instance.unstub(:dashboard_new_alias?)
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

    def test_update_ticket_with_type_service_task_without_mandatory_custom_fields
      perform_fsm_operations
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
      perform_fsm_operations
      params_hash = { email: Faker::Internet.email, description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                      priority: 2, status: 2, type: SERVICE_TASK_TYPE, responder_id: @agent.id, custom_fields: {cf_fsm_contact_name: "test",cf_fsm_service_location: "test", cf_fsm_phone_number: "test"} }      
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
    ensure
      @account.ticket_fields.find_by_name("email1_#{@account.id}").destroy
      cleanup_fsm
    end
  end
end

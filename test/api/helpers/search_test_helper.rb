['users_test_helper.rb', 'tickets_test_helper.rb', 'companies_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['contact_fields_helper.rb', 'ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module SearchTestHelper
  include ApiTicketsTestHelper
  include UsersTestHelper
  include CompaniesTestHelper
  include ContactFieldsHelper

  SEARCH_CONTEXTS_WITHOUT_DESCRIPTION = [:agent_insert_solution, :filtered_solution_search, :portal_based_solutions]
  SPOTLIGHT_SEARCH_CONTEXT = :agent_spotlight_solution

  STATUSES = {
    resolved_at: [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED],
    closed_at: [Helpdesk::Ticketfields::TicketStatus::CLOSED],
    pending_since: [Helpdesk::Ticketfields::TicketStatus::PENDING]
  }.freeze

  def create_search_ticket(params)
    cc_emails = params[:cc_emails] || []
    fwd_emails = params[:fwd_emails] || []
    test_ticket = Helpdesk::Ticket.new(status: params[:status],
                                       display_id: params[:display_id],
                                       priority: params[:priority],
                                       requester_id: default_requester_id,
                                       subject: params[:subject],
                                       responder_id: params[:responder_id],
                                       source: params[:source],
                                       ticket_type: params[:type],
                                       cc_email: Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
                                       created_at: params[:created_at],
                                       updated_at: params[:updated_at],
                                       account_id: @account.id,
                                       custom_field: params[:custom_field])
    test_ticket.build_ticket_body(description: Faker::Lorem.paragraph)
    test_ticket.group_id = params[:group_id]
    test_ticket.tag_names = params[:tags].join(',')
    test_ticket.save_ticket
    test_ticket
  end

  def create_search_contact(params)
    test_contact = User.new(name: params[:name],
                            email: params[:email],
                            customer_id: params[:customer_id],
                            twitter_id: params[:twitter_id],
                            mobile: params[:mobile],
                            phone: params[:phone],
                            time_zone: params[:time_zone],
                            language: params[:language],
                            helpdesk_agent: false,
                            account_id: @account.id,
                            custom_field: params[:custom_field],
                            created_at: params[:created_at],
                            updated_at: params[:updated_at])
    test_contact.tag_names = params[:tags].join(',') if params[:tags]
    test_contact.unique_external_id = params[:unique_external_id] if params[:unique_external_id]
    test_contact.save
    test_contact.update_attribute(:active, params[:active])
    test_contact
  end

  def create_search_company(params)
    test_company = Company.new(name: params[:name],
                               description: params[:description],
                               domains: params[:domains],
                               account_id: @account.id,
                               custom_field: params[:custom_field],
                               created_at: params[:created_at],
                               updated_at: params[:updated_at])
    test_company.save
    test_company
  end

  def default_requester_id
    @id ||= @account.all_contacts.first.id
  end

  def ticket_statuses
    @statuses ||= @account.ticket_statuses.map(&:status_id)
  end

  def clear_es(acid)
    ES_V2_SUPPORTED_TYPES.keys.each do |es_type|
      Search::V2::IndexRequestHandler.new(es_type, acid, nil).remove_by_query(account_id: acid)
    end
  end

  def write_data_to_es(acid)
    Sharding.select_shard_of(acid) do
      Account.find(acid).make_current
      Account.current.users.find_in_batches(batch_size: 300) do |users|
        users.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.tickets.find_in_batches(batch_size: 300) do |tickets|
        tickets.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.notes.exclude_source(%w(meta tracker)).find_in_batches(batch_size: 300) do |notes|
        notes.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.archive_tickets.find_in_batches(batch_size: 300) do |archive_tickets|
        archive_tickets.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.archive_notes.exclude_source('meta').find_in_batches(batch_size: 300) do |archive_notes|
        archive_notes.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.solution_articles.find_in_batches(batch_size: 300) do |articles|
        articles.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.topics.find_in_batches(batch_size: 300) do |topics|
        topics.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.posts.find_in_batches(batch_size: 300) do |posts|
        posts.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.companies.find_in_batches(batch_size: 300) do |companies|
        companies.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.tags.find_in_batches(batch_size: 300) do |tags|
        tags.map(&:sqs_manual_publish_without_feature_check)
      end
    end
    sleep(10)
  end

  def search_solution_article_pattern(article, context = SPOTLIGHT_SEARCH_CONTEXT)
    article_pattern = {
      id: article.parent_id,
      type: article.parent.art_type,
      category_id: article.parent.solution_category_meta.id,
      folder_id: article.parent.solution_folder_meta.id,
      folder_visibility: article.parent.solution_folder_meta.visibility,
      agent_id: article.user_id,
      path: article.to_param,
      modified_at: article.modified_at.try(:utc).try(:iso8601),
      modified_by: article.modified_by,
      language_id: article.language_id,
      language: article.language_code
    }
    article_pattern.merge!(search_article_content_pattern(article.draft || article, context))
    article_pattern.merge!(parents_info(article, context))
    article_pattern
  end

  def public_search_solution_article_pattern(article, context = SPOTLIGHT_SEARCH_CONTEXT)
    search_solution_article_pattern(article, context).except(:portal_ids)
  end

  def parents_info(article, context)
    category_meta = article.solution_folder_meta.solution_category_meta
    parents_info_pattern = {
      category_name: category_meta.safe_send("#{language_short_code(article)}_category").name,
      folder_name: article.solution_folder_meta.safe_send("#{language_short_code(article)}_folder").name
    }
    parents_info_pattern[:portal_ids] = category_meta.portal_solution_categories.map(&:portal_id) if context == SPOTLIGHT_SEARCH_CONTEXT
    parents_info_pattern
  end

  def search_article_content_pattern(item, context)
    search_article_content_pattern = {
      title: item.title,
      status: item.status,
      created_at: item.created_at.try(:utc).try(:iso8601),
      updated_at: item.updated_at.try(:utc).try(:iso8601)
    }
    search_article_content_pattern.merge!(description_hash(item)) unless context && SEARCH_CONTEXTS_WITHOUT_DESCRIPTION.include?(context)
    search_article_content_pattern
  end

  def description_hash(item)
    {
      description: item.description,
      description_text: item.is_a?(Solution::Article) ? item.desc_un_html : un_html(item.description),
    }
  end

  def language_short_code(article)
    Language.find(article.language_id).to_key
  end

  def topic_pattern(topic)
    category = topic.forum.forum_category
    {
      id: topic.id,
      title: topic.title,
      forum_id: topic.forum_id,
      user_id: topic.user_id,
      locked: topic.locked,
      published: topic.published,
      stamp_type: topic.stamp_type,
      replied_by: topic.replied_by,
      user_votes: topic.user_votes,
      merged_topic_id: topic.merged_topic_id,
      comments_count: topic.posts_count,
      sticky: topic.sticky.to_s.to_bool,
      created_at: topic.created_at.try(:utc),
      updated_at: topic.updated_at.try(:utc),
      replied_at: topic.replied_at.try(:utc),
      hits: topic.hits,
      category_id: category.id,
      category_name: category.name,
      forum_name: topic.forum.name,
      description_text: topic.topic_desc
    }
  end

  def search_ticket_pattern(ticket)
    ticket_pattern = {
      id: ticket.id,
      tags: ticket.tags,
      responder_id: ticket.responder_id,
      created_at: ticket.created_at.try(:utc).try(:iso8601),
      subject: ticket.subject,
      requester_id: ticket.requester_id,
      group_id: ticket.group_id,
      status: ticket.status,
      source: ticket.source,
      priority: ticket.priority,
      archived: ticket.archive,
      description_text: ticket.description,
      due_by: ticket.due_by.try(:utc).try(:iso8601),
      stats: stats(ticket)
    }
    ticket_pattern[:requester] = requester_pattern(ticket.requester) if ticket.requester
    ticket_pattern
  end

  def requester_pattern(requester)
    req_hash = {
      name: requester.name,
      job_title: requester.job_title,
      email: requester.email,
      phone: requester.phone,
      mobile: requester.mobile,
      twitter_id: requester.twitter_id,
      id: requester.id,
      has_email: requester.email.present?,
      active: requester.active,
      avatar: requester.avatar,
      language: requester.language,
      address: requester.address
    }
    req_hash[:facebook_id] = requester.fb_profile_id if requester.fb_profile_id
    req_hash[:external_id] = requester.external_id if requester.external_id
    default_company = get_default_company(requester)
    req_hash[:company] = company_hash(default_company) if default_company.present? && default_company.company.present?
    req_hash[:other_companies] = other_companies_hash(true, requester) if Account.current.multiple_user_companies_enabled? && requester.company_id.present?
    req_hash[:unique_external_id] = requester.unique_external_id if Account.current.unique_contact_identifier_enabled? && requester.unique_external_id
    req_hash
  end

  def stats(ticket)
    {
      agent_responded_at: ticket.ticket_states.agent_responded_at.try(:utc).try(:iso8601),
      requester_responded_at: ticket.ticket_states.requester_responded_at.try(:utc).try(:iso8601),
      first_responded_at: ticket.ticket_states.first_response_time.try(:utc).try(:iso8601),
      status_updated_at: ticket.ticket_states.status_updated_at.try(:utc).try(:iso8601),
      reopened_at: ticket.ticket_states.opened_at.try(:utc).try(:iso8601)
    }.merge(status_based_stats(ticket))
  end

  def status_based_stats(ticket)
    STATUSES.each_with_object({}) do |(key, value), res|
      res[key] = ticket.ticket_states.safe_send(key).try(:utc).try(:iso8601) || (value.include?(ticket.status) ? ticket.ticket_states.updated_at.try(:utc).try(:iso8601) : nil)
      res
    end
  end

  def private_search_contact_pattern(contact)
    contact_pattern = {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone: contact.phone,
      mobile: contact.mobile,
      company_id: default_company_id(contact),
      company_name: contact.company_name,
      avatar: Hash,
      twitter_id: contact.twitter_id,
      facebook_id: contact.fb_profile_id,
      external_id: contact.external_id,
      unique_external_id: contact.unique_external_id,
      other_emails: other_emails(contact),
      created_at: contact.created_at.try(:utc).try(:iso8601),
      updated_at: contact.updated_at.try(:utc).try(:iso8601)
    }
    contact_pattern[:other_companies] = other_companies(contact) if @account.multiple_user_companies_enabled?
    contact_pattern
  end

  def default_company_id(contact)
    default_company(contact) ? default_company(contact).company_id : nil
  end

  def default_company(contact)
    @default_user_company ||= contact.user_companies.select(&:default).first
  end

  def other_emails(contact)
    contact.user_emails.reject(&:primary_role).map(&:email)
  end

  def other_companies(contact)
    contact.user_companies.preload(:company).map do |user_company|
      contact_company_pattern(user_company) if user_company.company.present? && !user_company.default
    end.compact
  end

  def contact_company_pattern(user_company)
    {
      id: user_company.company_id,
      view_all_tickets: user_company.client_manager,
      name: user_company.company.name,
      avatar: Hash
    }
  end

  def private_search_company_pattern(company)
    user_count = company.users.count
    {
      id: company.id,
      name: company.name,
      description: company.description,
      note: company.note,
      domains: domains(company),
      created_at: company.created_at.try(:utc),
      updated_at: company.updated_at.try(:utc),
      custom_fields: construct_custom_field_hash(company),
      user_count: user_count
    }
  end

  def construct_custom_field_hash(company)
    custom_field_hash = {}
    company.custom_field.each do |k,v|
      new_key = k.sub('cf_','')
      custom_field_hash[new_key] = v
    end
    custom_field_hash
  end

  def public_search_company_pattern(company)
    public_hash = private_search_company_pattern(company).except(:user_count,:custom_fields)
    public_hash[:custom_fields] = Hash
  end

  def domains(company)
    company.domains.nil? ? [] : company.domains.split(',')
  end

  def stub_private_search_response(objects)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new(objects, { total_entries: objects.size }))
    yield
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def stub_private_search_response_with_object(object)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(object)
    yield
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def stub_public_search_response(objects)
    SearchService::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new(objects, { total_entries: objects.size }))
    yield
  ensure
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def stub_private_search_response_with_empty_array
    SearchService::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([], total_entries: 0))
    yield
  ensure
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end
end

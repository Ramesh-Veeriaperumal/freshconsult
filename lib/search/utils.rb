# encoding: utf-8

# _Note_: All app related search data like constants, etc.
#
class Search::Utils

  MAX_PER_PAGE          = 30
  DEFAULT_PAGE          = 1
  DEFAULT_OFFSET        = 0
  COUNT_REQUEST_PER_PAGE = 1

  # Normal templates do not work for pubsupport/souq
  #
  SPECIAL_TEMPLATES = {
    portal_spotlight_global:        'portalSpotlightGlobalSpecial',
    portal_spotlight_global_exact:  'portalSpotlightGlobalExactSpecial',
    portal_spotlight_ticket:        'portalSpotlightTicketSpecial',
    portal_spotlight_ticket_exact:  'portalSpotlightTicketExactSpecial',
    agent_spotlight_global:         'agentSpotlightGlobalSpecial',
    agent_spotlight_global_exact:   'agentSpotlightGlobalExactSpecial',
    agent_spotlight_suggest:        'agentSpotlightSuggestSpecial',
    agent_spotlight_suggest_exact:  'agentSpotlightSuggestExactSpecial',
    agent_spotlight_ticket:         'agentSpotlightTicketSpecial',
    agent_spotlight_ticket_exact:   'agentSpotlightTicketExactSpecial',
    merge_display_id:               'mergeDisplayIdSpecial',
    merge_subject:                  'mergeSubjectSpecial',
    merge_subject_exact:            'mergeSubjectExactSpecial',
    assoc_tickets_display_id:       'assocTicketsDisplayIdSpecial',
    assoc_tickets_subject:          'assocTicketsSubjectSpecial',
    mobile_suggest_tickets:         'mobileSuggestTicketsSpecial',
    mobile_suggest_global:          'mobileSuggestGlobalSpecial',
    hstickets_dispid:               'hsTicketsByDisplayIdSpecial',
    hstickets_subject:              'hsTicketsBySubjectSpecial'
  }

  # _Note_: Query Template name to use in ES.
  #
  TEMPLATE_BY_CONTEXT   = {
    portal_spotlight_global:          'portalSpotlightGlobal',
    portal_spotlight_global_exact:    'portalSpotlightGlobalExact',
    portal_spotlight_ticket:          'portalSpotlightTicket',
    portal_spotlight_ticket_exact:    'portalSpotlightTicketExact',
    portal_spotlight_solution:        'portalSpotlightSolution',
    portal_spotlight_solution_exact:  'portalSpotlightSolutionExact',
    portal_spotlight_topic:           'portalSpotlightTopic',
    portal_spotlight_topic_exact:     'portalSpotlightTopicExact',
    portal_related_articles:          'portalRelatedArticles',
    ko_portal_spotlight_global:             'koreanPortalSpotlightGlobal',
    ko_portal_spotlight_global_exact:       'koreanPortalSpotlightGlobalExact',
    ko_portal_spotlight_solution:           'koreanPortalSpotlightSolution',
    ko_portal_spotlight_solution_exact:     'koreanPortalSpotlightSolutionExact',
    ko_portal_related_articles:             'koreanPortalRelatedArticles',
    ru_ru_portal_spotlight_global:          'russianPortalSpotlightGlobal',
    ru_ru_portal_spotlight_global_exact:    'russianPortalSpotlightGlobalExact',
    ru_ru_portal_spotlight_solution:        'russianPortalSpotlightSolution',
    ru_ru_portal_spotlight_solution_exact:  'russianPortalSpotlightSolutionExact',
    ru_ru_portal_related_articles:          'russianPortalRelatedArticles',
    ja_jp_portal_spotlight_global:          'japanesePortalSpotlightGlobal',
    ja_jp_portal_spotlight_global_exact:    'japanesePortalSpotlightGlobalExact',
    ja_jp_portal_spotlight_solution:        'japanesePortalSpotlightSolution',
    ja_jp_portal_spotlight_solution_exact:  'japanesePortalSpotlightSolutionExact',
    ja_jp_portal_related_articles:          'japanesePortalRelatedArticles',
    zh_cn_portal_spotlight_global:          'chinesePortalSpotlightGlobal',
    zh_cn_portal_spotlight_global_exact:    'chinesePortalSpotlightGlobalExact',
    zh_cn_portal_spotlight_solution:        'chinesePortalSpotlightSolution',
    zh_cn_portal_spotlight_solution_exact:  'chinesePortalSpotlightSolutionExact',
    zh_cn_portal_related_articles:          'chinesePortalRelatedArticles',
    contact_merge:                    'contactMerge',
    contact_merge_exact:              'contactMergeExact',
    agent_autocomplete:               'agentAutocomplete',
    agent_autocomplete_exact:         'agentAutocompleteExact',
    requester_autocomplete:           'requesterAutocomplete',
    requester_autocomplete_exact:     'requesterAutocompleteExact',
    company_autocomplete:             'companyAutocomplete',
    company_autocomplete_exact:       'companyAutocompleteExact',
    tag_autocomplete:                 'tagAutocomplete',
    agent_insert_solution:            'agentInsertSolution',
    agent_insert_solution_exact:      'agentInsertSolutionExact',
    agent_spotlight_global:           'agentSpotlightGlobal',
    agent_spotlight_global_exact:     'agentSpotlightGlobalExact',
    agent_spotlight_suggest:          'agentSpotlightSuggest',
    agent_spotlight_suggest_exact:    'agentSpotlightSuggestExact',
    agent_spotlight_ticket:           'agentSpotlightTicket',
    agent_spotlight_ticket_exact:     'agentSpotlightTicketExact',
    agent_spotlight_solution:         'agentSpotlightSolution',
    agent_spotlight_solution_exact:   'agentSpotlightSolutionExact',
    ko_agent_spotlight_solution:            'koreanAgentSpotlightSolution',
    ko_agent_spotlight_solution_exact:      'koreanAgentSpotlightSolutionExact',
    ko_agent_insert_solution:               'koreanAgentInsertSolution',
    ko_agent_insert_solution_exact:         'koreanAgentInsertSolution',
    ru_ru_agent_spotlight_solution:         'russianAgentSpotlightSolution',
    ru_ru_agent_spotlight_solution_exact:   'russianAgentSpotlightSolutionExact',
    ru_ru_agent_insert_solution:            'russianAgentInsertSolution',
    ru_ru_agent_insert_solution_exact:      'russianAgentInsertSolution',
    ja_jp_agent_spotlight_solution:         'japaneseAgentSpotlightSolution',
    ja_jp_agent_spotlight_solution_exact:   'japaneseAgentSpotlightSolutionExact',
    ja_jp_agent_insert_solution:            'japaneseAgentInsertSolution',
    ja_jp_agent_insert_solution_exact:      'japaneseAgentInsertSolution',
    zh_cn_agent_spotlight_solution:         'chineseAgentSpotlightSolution',
    zh_cn_agent_spotlight_solution_exact:   'chineseAgentSpotlightSolutionExact',
    zh_cn_agent_insert_solution:            'chineseAgentInsertSolution',
    zh_cn_agent_insert_solution_exact:      'chineseAgentInsertSolution',
    agent_spotlight_topic:            'agentSpotlightTopic',
    agent_spotlight_topic_exact:      'agentSpotlightTopicExact',
    agent_spotlight_customer:         'agentSpotlightCustomer',
    agent_spotlight_customer_exact:   'agentSpotlightCustomerExact',
    merge_display_id:                 'mergeDisplayId',
    merge_subject:                    'mergeSubject',
    merge_subject_exact:              'mergeSubjectExact',
    merge_requester:                  'mergeRequester',
    merge_topic_search:               'mergeTopicSearch',
    merge_topic_search_exact:         'mergeTopicSearchExact',
    assoc_tickets_display_id:         'assocTicketsDisplayId',
    assoc_tickets_subject:            'assocTicketsSubject',
    assoc_tickets_requester:          'assocTicketsRequester',
    assoc_recent_trackers:            'assocRecentTrackers',
    mobile_suggest_tickets:           'mobileSuggestTickets',
    mobile_suggest_customers:         'mobileSuggestCustomers',
    mobile_suggest_solutions:         'mobileSuggestSolutions',
    mobile_suggest_topics:            'mobileSuggestTopics',
    mobile_suggest_global:            'mobileSuggestGlobal',
    ff_contact_by_phone:              'freshfoneContactByNumbers',
    ff_contact_by_caller:             'freshfoneContactByCaller',
    ff_contact_by_numfields:          'freshfoneContactByNumberfields',
    company_v2_search:                'companyApiSearch',
    hstickets_dispid:                 'hsTicketsByDisplayId',
    hstickets_subject:                'hsTicketsBySubject',
    filtered_ticket_search:           'filteredTicketSearch',
    filtered_ticket_search_exact:     'filteredTicketSearchExact',
    filtered_contact_search:          'filteredContactSearch',
    filtered_company_search:          'filteredCompanySearch',
    search_ticket_api:                'searchTicketApi',
    search_contact_api:               'searchContactApi',
    search_company_api:               'searchCompanyApi',
    filtered_solution_search:         'filteredSolutionSearch',
    portal_company_users:             'portalCompanyUsers',
    search_automation:                'searchAutomation'
  }

  FUZZY_TEXT = 'Fuzzy'

  FUZZY_TEMPLATE_BY_CONTEXT = {
    agent_spotlight_solution: 'agentSpotlightSolutionFuzzy',
    agent_insert_solution: 'agentInsertSolutionFuzzy',
    agent_spotlight_global: 'agentSpotlightGlobalFuzzy',
    agent_spotlight_suggest: 'agentSpotlightSuggestFuzzy',
    filtered_solution_search: 'filteredSolutionSearchFuzzy',
    portal_spotlight_global: 'portalSpotlightGlobalFuzzy',
    portal_spotlight_solution: 'portalSpotlightSolutionFuzzy'
  }.freeze

  # _Note_: Parent ID to be used for routing.
  #
  PARENT_BASED_ROUTING  = {
    'Helpdesk::Note'        => :notable_id,
    'Helpdesk::ArchiveNote' => :archive_ticket_id,
    'Post'                  => :topic_id
  }
  SEARCH_LOGGING        = {
    all:      1,
    request:  2,
    response: 3
  }

  MQ_TEMPLATES_MAPPING = [
    #[document name, account.features?(:feature_name), user privilege, klasses]
    ['agentSpotlightTicket', nil, :manage_tickets, ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']],
    ['agentSpotlightSolution', nil, :view_solutions, ['Solution::Article']],
    ['agentSpotlightTopic', 'forums', :view_forums, ['Topic']],
    ['agentSpotlightCustomer', nil, :view_contacts, ['User', 'Company']]
  ]

  TEMPLATE_MAPPING_TO_FEATURES = Hash[*MQ_TEMPLATES_MAPPING.map { |i| [i[0], i[1]] }.flatten]

  TEMPLATE_MAPPING_TO_PRIVILEGES = Hash[*MQ_TEMPLATES_MAPPING.map { |i| [i[0], i[2]] }.flatten]

  TEMPLATE_TO_CLASS_MAPPING = Hash[*MQ_TEMPLATES_MAPPING.map { |i| [i[0].underscore.to_sym, i[3]] }.flatten(1)]

  MQ_TEMPLATES = MQ_TEMPLATES_MAPPING.map(&:first)
  MQ_CONTEXTS  = ['spotlight']
  MQ_SPOTLIGHT_SEARCH_LIMIT = 3
  MQ_MAX_LIMIT = 10   # Can increase when Search service increases the limit on their end

  # Load ActiveRecord objects
  #
  def self.load_records(es_results, model_and_assoc, args={})
    records = {}

    # Load each type's results via its model
    #
    (es_results['hits']['hits'].presence || {}).group_by { |item| item['_type'] }.each do |type, items|
      if items.empty?
        records[type] = []
      else
        records[type] = model_and_assoc[type][:model]
                                        .constantize
                                        .where(account_id: args[:current_account_id], id: items.map { |h| h['_id'] })
                                        .preload(model_and_assoc[type][:associations])
                                        .compact
      end
    end

    # For sorting in the same order received by ES
    # For highlighting also
    # Need to think better logic if needed
    #
    result_set = es_results['hits']['hits'].map do |item|
      detected = records[item['_type']].detect do |record|
        record.id.to_s == item['_id'].to_s
      end

      item['highlight'].keys.each do |field|
        detected.safe_send("highlight_#{field}=", [*item['highlight'][field]].join(' ... ')) if detected.respond_to?("highlight_#{field}=")
      end if item['highlight'].present?

      detected
    end

    wrap_paginate(result_set, args[:page].to_i, args[:es_offset], es_results['hits']['total'].to_i)
  end

  def self.exact_match?(search_term)
    search_term.present? and (search_term.start_with?('<','"') && search_term.end_with?('>', '"'))
  end

  def self.extract_term(search_term, exact_match=false)
    # Removing <>/"" if exact match
    term = (exact_match ? search_term.to_s.gsub(/^<?"?|"?>?$/,'').squish : search_term)

    # Removing tags and spl chars from ends
    ActionController::Base.helpers.strip_tags(term).gsub(/^\*|\*$/, '').squish
  end

  # Returns partial/exact match template
  #
  def self.template_context(context, exact_match, locale=nil)
    template_key = (exact_match ? "#{context}_exact" : context).to_sym

    lang_template_key = [locale.underscore, template_key].join('_').to_sym if locale.present?
    template_key = lang_template_key if TEMPLATE_BY_CONTEXT.has_key?(lang_template_key)

    template_key = context unless TEMPLATE_BY_CONTEXT.has_key?(template_key) # To-do: Bad hack. Revisit.
    template_key
  end

  def self.get_template_id(context, exact_match, locale=nil)
    template_key = template_context(context, exact_match, locale)
    if(Account.current.launched?(:es_v2_splqueries) && Search::Utils::SPECIAL_TEMPLATES.has_key?(template_key))
      Search::Utils::SPECIAL_TEMPLATES[template_key]
    elsif Account.current.launched?(:fuzzy_search) && Search::Utils::FUZZY_TEMPLATE_BY_CONTEXT.key?(template_key)
      Search::Utils::FUZZY_TEMPLATE_BY_CONTEXT[template_key]
    else
      Search::Utils::TEMPLATE_BY_CONTEXT[template_key]
    end
  end

  def self.context_mapping(context)
    if (Account.current.launched?(:es_v2_splqueries) && Search::Utils::SPECIAL_TEMPLATES.has_value?(context))
      context.sub('Exact','').sub('Special','')
    elsif Account.current.launched?(:fuzzy_search)
      context.gsub(Search::Utils::FUZZY_TEXT, '')
    else
      context.sub('Exact','')
    end
  end

  private

    def self.wrap_paginate(result_set, page_number, es_offset, total_entries)
      Search::V2::PaginationWrapper.new(result_set, { page: page_number,
                                          from: es_offset,
                                          total_entries: total_entries })
    end
end

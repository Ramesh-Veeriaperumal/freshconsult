# encoding: utf-8

# _Note_: All app related search data like constants, etc.
#
class Search::Utils

  MAX_PER_PAGE          = 30
  DEFAULT_PAGE          = 1
  DEFAULT_OFFSET        = 0
  TEMPLATE_BY_CONTEXT   = {
    portal_spotlight:           'portalSpotlight',
    portal_article_search:      'portalArticleSearch',
    agent_autocomplete:         'agentAutocomplete',
    requester_autocomplete:     'requesterAutocomplete',
    company_autocomplete:       'companyAutocomplete',
    tag_autocomplete:           'tagAutocomplete',
    agent_spotlight_global:     'agentSpotlightGlobal',
    agent_spotlight_ticket:     'agentSpotlightTicket',
    agent_spotlight_solution:   'agentSpotlightSolution',
    agent_spotlight_topic:      'agentSpotlightTopic',
    agent_spotlight_customer:   'agentSpotlightCustomer',
    merge_display_id:           'mergeDisplayId',
    merge_subject:              'mergeSubject',
    merge_requester:            'mergeRequester'
  }
  PARENT_BASED_ROUTING  = {
    'Helpdesk::Note'        => :notable_id,
    'Helpdesk::ArchiveNote' => :notable_id,
    'Post'                  => :topic_id
  }
  SEARCH_LOGGING        = {
    all:      1,
    request:  2,
    response: 3
  }

  # Load ActiveRecord objects
  #
  def self.load_records(es_results, model_and_assoc, args={})
    records = {}
    
    # Load each type's results via its model
    #
    es_results['hits']['hits'].group_by { |item| item['_type'] }.each do |type, items| 
      if items.empty?
        records[type] = []
      else
        records[type] = model_and_assoc[type][:model]
                                        .constantize
                                        .where(account_id: args[:current_account_id], id: items.map { |h| h['_id'] })
                                        .preload(model_and_assoc[type][:associations])
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
        detected.send("highlight_#{field}=", item['highlight'][field].to_s) if detected.respond_to?("highlight_#{field}=")
      end if item['highlight'].present?

      detected
    end

    wrap_paginate(result_set, args[:page].to_i, args[:es_offset], es_results['hits']['total'].to_i)
  end

  # Used for setting the version parameter sent to ES
  # Value is time in microsecond precision
  #
  def self.es_version
    (Time.zone.now.to_f * 1000000).ceil
  end
  
  private
    
    def self.wrap_paginate(result_set, page_number, es_offset, total_entries)
      PaginationWrapper.new(result_set, { page: page_number,
                                          from: es_offset,
                                          total_entries: total_entries })
    end

    #_Note_: Not sure if array is the right superclass. But works for now.
    class PaginationWrapper < Array

      attr_accessor :total, :options, :records

      def initialize(result_set, es_options={})
        @total    = es_options[:total_entries]
        @options  = {
          :page   => es_options[:page] || 1,
          :from   => es_options[:from] || 0
        }
        super(result_set)
      end

      #=> Will Paginate Support(taken from Tire) <=#
      def total_entries
        @total
      end

      def per_page
        MAX_PER_PAGE.to_i
      end

      def total_pages
        ( @total.to_f / per_page ).ceil
      end

      def current_page
        if @options[:page]
          @options[:page].to_i
        else
          (per_page + @options[:from].to_i) / per_page
        end
      end

      def previous_page
        current_page > 1 ? (current_page - 1) : nil
      end

      def next_page
        current_page < total_pages ? (current_page + 1) : nil
      end

      def offset
        per_page * (current_page - 1)
      end

      def out_of_bounds?
        current_page > total_pages
      end
    end
end
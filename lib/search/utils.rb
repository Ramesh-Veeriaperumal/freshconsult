# encoding: utf-8
class Search::Utils

  MAX_PER_PAGE        = 30
  TEMPLATE_BY_CONTEXT = {
    :portal_spotlight       => 'portalSpotlight',
    :portal_article_search  => 'portalArticleSearch',
    :agent_autocomplete     => 'agentAutocomplete',
    :requester_autocomplete => 'requesterAutocomplete',
    :company_autocomplete   => 'companyAutocomplete',
    :tag_autocomplete       => 'tagAutocomplete',
    :agent_spotlight        => 'agentSpotlight',
    :merge_display_id       => 'mergeDisplayId',
    :merge_subject          => 'mergeSubject',
    :merge_requester        => 'mergeRequester'
  }

  # Load ActiveRecord objects
  #
  def self.load_records(es_results, model_and_assoc, current_account_id)
    records = {}
    
    # Load each type's results via its model
    #
    es_results['hits']['hits'].group_by { |item| item['_type'] }.each do |type, items| 
      if items.empty?
        records[type] = []
      else
        records[type] = model_and_assoc[type][:model]
                                        .constantize
                                        .where(account_id: current_account_id, id: items.map { |h| h['_id'] })
                                        .preload(model_and_assoc[type][:associations])
      end
    end

    # For sorting in the same order received by ES
    # For highlighting also
    # Need to think better logic if needed
    #
    es_results['hits']['hits'].map do |item|
      detected = records[item['_type']].detect do |record|
        record.id.to_s == item['_id'].to_s
      end

      item['highlight'].keys.each do |field|
        detected.send("highlight_#{field}=", item['highlight'][field].to_s) if detected.respond_to?("highlight_#{field}=")
      end if item['highlight'].present?

      detected
    end
  end

  # Used for setting the version parameter sent to ES
  # Value is time in microsecond precision
  #
  def self.es_version
    (Time.zone.now.to_f * 1000000).ceil
  end

end
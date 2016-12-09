module SearchHelper
  def lookup_and_change_params
    params[:search_conditions] = {}
    flexilookup = searchable_text_ff_fields
    (params.keys & (flexilookup.keys | ApiTicketConstants::SEARCH_ALLOWED_DEFAULT_FIELDS)).each do |field|
      search_key = flexilookup[field] || field
      set_search_conditions(search_key, params[field].to_s.split(','))
    end
  end

  def searchable_text_ff_fields
    @ff ||= current_account.flexifields_with_ticket_fields_from_cache.collect { |ff| [TicketDecorator.display_name(ff.flexifield_alias), ff.flexifield_name] if ff.flexifield_name =~ /^ffs/ }.compact.to_h
  end

  def set_search_conditions(key, value)
    value = [*value]
    value.compact!
    params[:search_conditions][key] = value unless value.blank?
  end

  # Temp functions
  def query_es(terms, resource = :tickets, page=1)
    url = ""
    if resource == :tickets
      url = "http://localhost:9200/tickets_p1s1v1/_search"
    elsif resource == :contacts
      url = "http://localhost:9200/users_p1s1v1/_search"
    elsif resource == :companies
      url = "http://localhost:9200/companies_p1s1v1/_search"
    end
    search_query = { _source: 'false', query: { bool: { filter: [ terms ] } }, size: 30, from: ((page || 1) - 1)  * 30  }
    begin
      response = Search::V2::Utils::EsClient.new(:get, 
                            url, 
                            { routing: current_account.id },
                            search_query.to_json,
                            Search::Utils::SEARCH_LOGGING[:request],
                            UUIDTools::UUID.timestamp_create.hexdigest,
                            current_account.id,
                            'cluster1',
                            nil
                          ).response
    rescue RestClient::Exception => exception
      response = exception.response.body
    rescue Exception => exception
      response = exception.message
    end
    return ActionController::Parameters.new(response)
  end
end

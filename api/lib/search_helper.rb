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

  # API Search controller
  def ids_from_esv2_response(json)
    result = ActionController::Parameters.new(JSON.parse json)
    if result[:hits][:hits].any?
      result[:hits][:hits].map{|x| x["_id"].to_i}
    else
      []
    end
  end

  # Temp functions
  def populate_es
    all_tickets = current_account.tickets
    all_tickets.each do |ticket|
      url = "http://localhost:9200/ticket_index/ticket/#{ticket.id}"
      site = RestClient::Resource.new(url)
      begin
        response = site.put(ticket.to_esv2_json, :content_type=>'application/json')
      rescue RestClient::Exception
        puts "For ticket #{ticket.id} \nResponse Code: #{exception.response.code} \nResponse Body: #{exception.response.body} \n"
      end
    end

    all_contacts = current_account.contacts
    all_contacts.each do |contact|
      url = "http://localhost:9200/contact_index/contact/#{contact.id}"
      site = RestClient::Resource.new(url)
      begin
        response = site.put(contact.to_esv2_json, :content_type=>'application/json')
      rescue RestClient::Exception
        puts "For contact #{contact.id} \nResponse Code: #{exception.response.code} \nResponse Body: #{exception.response.body} \n"
      end
    end
  end

  def query_es(terms, resource = :tickets)
    url = ""
    if resource == :tickets
      #http://localhost:9200/tickets_p1s1v1/_search
      url = "http://localhost:9200/ticket_index/ticket/_search"
    elsif resource == :contacts
      #http://localhost:9200/users_p1s1v1/_search
      url = "http://localhost:9200/contact_index/contact/_search"
    end
    search_query = { _source: 'false', query: { bool: { filter: [ terms ] } } }
    begin
      response = RestClient::Request.execute(method: :get, url: url, payload: search_query.to_json)
    rescue RestClient::Exception => exception
      response = { error: "Response Code: #{exception.response.code} | Response Body: #{exception.response.body} \n" }
    end
    return response
  end
end

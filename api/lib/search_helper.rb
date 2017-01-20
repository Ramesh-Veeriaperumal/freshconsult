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
end

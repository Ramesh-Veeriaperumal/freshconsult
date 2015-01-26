#encoding: utf-8
module Search::KeywordSearch::Lookup

  def self.included(base)
    base.before_filter :lookup_and_change_params
  end

  def lookup_and_change_params
    params[:search_conditions] = Hash.new

    (params.keys & flexilookup.keys).each do |field|
      set_search_conditions("flexifield.#{flexilookup[field]}", params[field])
    end
  end

  private

    def flexilookup
      @ff ||= current_account.flexifields_with_ticket_fields_from_cache.map { |ff| [ff.flexifield_alias, ff.flexifield_name] }.to_h
    end

    def set_search_conditions key, value
      value = [*value]
      value.compact!
      params[:search_conditions][key] = value unless value.blank?
    end          
end
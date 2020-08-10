class Freshfone::Filters::CallFilter < Wf::Filter
  ALLOWED_ORDERING = [ 'created_at', 'call_duration', 'call_cost' ]
  ALLOWED_SORTING = ['asc', 'desc']
  def results
    @results ||= begin
      handle_empty_filter! 
      recs = model_class.order(order_clause).where(sql_conditions).preload(
        [:ticket, :note, :recording_audio, :caller, :meta, :freshfone_number, agent: [:avatar], :customer => [:avatar]]
        ).paginate(page: page, per_page: per_page)
      recs.wf_filter = self
      recs
    end
  end

  def deserialize_from_params_with_validation(params)
    params["wf_order"] = nil unless ALLOWED_ORDERING.include?(params["wf_order"])
    deserialize_from_params(params)
  end

  def deserialize_from_params(params)
    @conditions = []
    @match                = params[:wf_match]       || :all
    @key                  = params[:wf_key]         || self.id.to_s
    self.model_class_name = params[:wf_model]       if params[:wf_model]
    
    @per_page             = params[:wf_per_page]    || default_per_page
    @page                 = params[:page]           || 1
    @order_type           = ALLOWED_SORTING.include?(params[:wf_order_type]) ? params[:wf_order_type] : default_order_type
    @order                = ALLOWED_ORDERING.include?(params[:wf_order] ) ? params[:wf_order] : default_order
    
    self.id   =  params[:wf_id].to_i  unless params[:wf_id].blank?
    self.name =  params[:wf_name]     unless params[:wf_name].blank?
    
    @fields = []
    unless params[:wf_export_fields].blank?
      params[:wf_export_fields].split(",").each do |fld|
        @fields << fld.to_sym
      end
    end

    if params[:wf_export_format].blank?
      @format = :html
    else  
      @format = params[:wf_export_format].to_sym
    end
    
    action_hash = []
    custom_condition_hash = []
    if params[:data_hash].blank? 
      action_hash = default_filter unless params[:format] == "nmobile"
    else
      action_hash = params[:data_hash]
      action_hash = ActiveSupport::JSON.decode params[:data_hash] if !params[:data_hash].kind_of?(Array)
    end

    action_hash.each do |filter|
      if filter["condition"].eql?("call_type")
      custom_condition_hash <<  add_call_type_conditions(filter)
      elsif  filter["condition"].eql?('created_at')
        add_created_at_conditions(filter)
      else
        add_condition(filter["condition"],filter["operator"].to_sym, filter["value"]) unless filter["value"].nil?
      end
    end

    custom_condition_hash.each do |filters|
      filters.each do |filter|
        add_condition(filter["condition"],filter["operator"].to_sym, filter["value"]) unless filter["value"].nil?
      end
    end

    if params[:wf_submitted] == 'true'
      validate!
    end

    return self
  end

  def definition
    @definition ||= begin
      defs = {}
      model_columns.each do |col|
        defs[col.name.to_sym] = default_condition_definition_for(col.name, col.sql_type)
      end
      
      inner_joins.each do |inner_join|
        join_class = inner_join.first.to_s.camelcase.constantize        
        join_class.columns.each do |col|
          defs[:"#{join_class.to_s.underscore}.#{col.name.to_sym}"] = default_condition_definition_for(col.name, col.sql_type)
        end
      end
      defs
    end
  end

  def default_order
    'created_at'
  end

  def add_call_type_conditions(filter)
    case filter["value"]
      when 'received' then
        return [{ "condition" => "call_type", "operator" => "is", "value" =>"#{Freshfone::Call::CALL_TYPE_HASH[:incoming]}"},
          { "condition" => "call_status", "operator" => "is_not", "value" => "#{Freshfone::Call::CALL_STATUS_HASH[:blocked]}"}]
      when 'dialed' then
        return [{ "condition" => "call_type", "operator" => "is", "value" =>"#{Freshfone::Call::CALL_TYPE_HASH[:outgoing]}"},
          { "condition" => "call_status", "operator" => "is_not", "value" => "#{Freshfone::Call::CALL_STATUS_HASH[:blocked]}"}]
      when 'missed' then
        return [{ "condition" => "call_status", "operator" => "is_in", 
              "value" => "#{Freshfone::Call::CALL_STATUS_HASH[:'no-answer']},#{Freshfone::Call::CALL_STATUS_HASH[:busy]}"},
                  { "condition" => "call_type", "operator" => "is", "value" =>"#{Freshfone::Call::CALL_TYPE_HASH[:incoming]}"}]
      when 'voicemail' then
        return [{ "condition" => "call_status", "operator" => "is", "value" => "#{Freshfone::Call::CALL_STATUS_HASH[:voicemail]}"}]
      when 'blocked' then
        return [{ "condition" => "call_status", "operator" => "is", "value" => "#{Freshfone::Call::CALL_STATUS_HASH[:blocked]}"}]    
    end
  end

  def add_created_at_conditions(filter)
    date_range = filter["value"]
    date_range = date_range.split('-')
    value = []
    value << date_range[0].to_date.beginning_of_day()
    value << (date_range[1] || date_range[0]).to_date.end_of_day()
    add_condition(filter["condition"],filter["operator"],value)
  end

  def default_filter
    date_range = "#{(Time.now.utc.ago 7.days).strftime("%d %B %Y")} - #{(Date.today).strftime("%d %B %Y")}"
    return [{ "condition" => "created_at", "operator" => "is_in_the_range", "value" => date_range } ]    
  end

end
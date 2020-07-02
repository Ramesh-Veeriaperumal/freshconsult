class PrivateApiGroupValidation < ApiGroupValidation
  include GroupConstants
  CHECK_PARAMS_SET_FIELDS=["round_robin_type","capping_limit","allow_agents_to_change_availability"].freeze
  attr_accessor   :round_robin_type, :capping_limit, :allow_agents_to_change_availability, :error_options, :group_type    

  validate :set_default_value

  validates :assignment_type, custom_numericality: {only_integer: true}, custom_inclusion: {in: ASSIGNMENT_TYPES}
  validates :round_robin_type, custom_numericality: {only_integer: true}, custom_inclusion: {in: ROUND_ROBIN_TYPES}
  validates :round_robin_type, custom_absence: { message: :invalid_field }, if: -> { !is_assignment_type_round_robin? }
  validates :capping_limit, custom_numericality: { only_integer: true, greater_than:0, lesser_than:100 }, required:true, if: -> { is_assignment_type_round_robin? && capping_limit_required? }  
  validates :capping_limit, custom_absence: { message: :invalid_field }, if: -> { !is_assignment_type_round_robin? || !capping_limit_required? }  
  validates :allow_agents_to_change_availability, data_type: {rules: 'Boolean'}
  validates :allow_agents_to_change_availability, custom_absence: {message: :invalid_field}, if: -> {is_assignment_type_no_assignment?}

  validate :round_robin_feature_check, if: -> { is_assignment_type_round_robin? }
  validate :lbrr_feature_check, if: -> { is_assignment_type_round_robin? && @request_params["round_robin_type"] == LOAD_BASED_ROUND_ROBIN }
  validate :sbrr_feature_check, if: -> { is_assignment_type_round_robin? && @request_params["round_robin_type"] == SKILL_BASED_ROUND_ROBIN }
  validate :lbrr_by_omniroute_feature_check, if: -> { is_assignment_type_round_robin? && @request_params["round_robin_type"] == LBRR_BY_OMNIROUTE }
  validate :ocr_feature_check, if: -> { is_assignment_type_ocr? || (is_assignment_type_round_robin? && @request_params["round_robin_type"] == LBRR_BY_OMNIROUTE)}
  validates :group_type, custom_inclusion: { in: proc { |x| x.account_group_types} , data_type: { rules: String } }, on: :create

 
  def initialize(request_params, item=nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
  end

  def set_default_value    
    @request_params["assignment_type"] = NO_ASSIGNMENT if assignment_type.nil? && create?   
    @request_params["round_robin_type"] = ROUND_ROBIN if assignment_type == ROUND_ROBIN_ASSIGNMENT && 
    @request_params["round_robin_type"].nil? && create?
  end 

  def round_robin_feature_check    
    if !Account.current.features?(:round_robin)
      errors[:assignment_type] << :require_feature 
      error_options.merge!(assignment_type:{ feature: 'round_robin'.titleize, code: :require_feature })
    end 
  end 

  def ocr_feature_check    
    if !Account.current.omni_channel_routing_enabled?
      errors[:assignment_type] << :require_feature 
      error_options.merge!(assignment_type:{ feature: 'omni_channel_routing'.titleize, code: :require_feature }) 
    end 
  end 

  def sbrr_feature_check    
    if !Account.current.skill_based_round_robin_enabled?
    errors[:round_robin_type] << :require_feature 
    error_options.merge!(round_robin_type:{ feature: 'skill_based_round_robin'.titleize, code: :require_feature })
    end 
  end

  def lbrr_by_omniroute_feature_check
    if !Account.current.lbrr_by_omniroute_enabled?
      errors[:assignment_type] << :require_feature 
      error_options.merge!(assignment_type:{ feature: 'lbrr_by_omniroute'.titleize, code: :require_feature }) 
    end 
  end

  def lbrr_feature_check    
    if !Account.current.round_robin_capping_enabled?
      errors[:round_robin_type] << :require_feature 
      error_options.merge!(round_robin_type:{ feature: 'load_based_round_robin'.titleize, code: :require_feature })
    end 
  end 
    
  def is_assignment_type_ocr?        
    if assignment_type.present? 
      assignment_type == OMNI_CHANNEL_ROUTING_ASSIGNMENT 
    else 
      ( update? && @item["ticket_assign_type"] == 10 )  
    end
  end 


  def is_assignment_type_round_robin?
    if assignment_type.present? 
      assignment_type == ROUND_ROBIN_ASSIGNMENT 
    else
      ( update? && @item["ticket_assign_type"] == 1 ) ||  
      ( update? && @item["ticket_assign_type"] == 2 ) ||
      ( update? && @item["ticket_assign_type"] == 12 )
    end
  end 

  def is_assignment_type_no_assignment?
    if assignment_type.present?
      assignment_type == NO_ASSIGNMENT && !Account.current.agent_statuses_enabled?
    else
      (update? && (@item['ticket_assign_type']).zero?) && !Account.current.agent_statuses_enabled?
    end
  end

  def capping_limit_required?
    round_robin_type = @request_params["round_robin_type"].present? ? @request_params["round_robin_type"] : 
    get_round_robin_type
    round_robin_type == LOAD_BASED_ROUND_ROBIN || round_robin_type==SKILL_BASED_ROUND_ROBIN
  end 
  
  def get_round_robin_type       
    rr_type=ROUND_ROBIN if @item["ticket_assign_type"]==1 && @item["capping_limit"]==0
    rr_type=LOAD_BASED_ROUND_ROBIN if @item["ticket_assign_type"]==1 && @item["capping_limit"]!=0     
    rr_type=SKILL_BASED_ROUND_ROBIN if @item["ticket_assign_type"]==2      
    rr_type=LBRR_BY_OMNIROUTE if @item["ticket_assign_type"]==12       
    rr_type      
  end

  def assignment_type
    @request_params["assignment_type"]
  end 
  
  def attributes_to_be_stripped
    ATTRIBUTES_TO_BE_STRIPPED
  end

  def create?
    @item.nil?
  end

  def update?
    @item.present?
  end

  def account_group_types
    Account.current.group_types_from_cache.map(&:name)
  end
end

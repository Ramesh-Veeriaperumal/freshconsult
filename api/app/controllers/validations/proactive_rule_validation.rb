class ProactiveRuleValidation < ApiValidation

  attr_accessor :filter, :conditions

  MATCH_TYPE = %w[all any].freeze

  validates :filter, data_type: { rules: Hash, required: true },
                     hash: {
                       match_type: {
                         data_type: { rules: String },
                         custom_inclusion: { in: MATCH_TYPE }
                       },
                       conditions: {
                         data_type: { rules: Array }
                       }
                     }, unless: -> { filter.blank? } 
  
  validate :check_match_type_presence, if: -> { filter.present? }, on: :create
  validate :check_conditions_presence, if: -> { filter.present? }, on: :create

  validates :conditions, data_type: { rules: Array },
                         array: {
                           data_type: { rules: Hash, required: true },
                           hash: {
                             entity: {
                               data_type: { rules: String, required: true }
                             },
                             field: {
                               data_type: { rules: String, required: true }
                             },
                             operator: {
                               data_type: { rules: String, required: true }
                             }
                           }
                         }, if: -> { errors[:filter].blank? && filter.present? } 
  
  validate :check_value_presence, if: -> { errors[:filter].blank? && errors[:conditions].blank? && filter.present? }


  private

  def check_value_presence
    conditions.each do |condition|
      if condition[:value].blank? && !(condition[:value].is_a?(FalseClass) || condition[:value].is_a?(TrueClass))
        errors[:filter] = :datatype_mismatch
        (error_options[:filter] ||= {}).merge!(expected_data_type: "valid data type", nested_field: "conditions.value", code: :missing_field)
      end
      break if errors[:filter].present?
    end
  end

  def check_match_type_presence
    if filter[:match_type].blank?
      errors[:filter] = :datatype_mismatch
      (error_options[:filter] ||= {}).merge!(expected_data_type: "String", nested_field: "match_type", code: :missing_field)
    end
  end

  def check_conditions_presence
    if conditions.blank?
      errors[:filter] = :datatype_mismatch
      (error_options[:filter] ||= {}).merge!(expected_data_type: Array, nested_field: :conditions, code: :missing_field)
    end
  end

end
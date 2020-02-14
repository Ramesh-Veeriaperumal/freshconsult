module HelpWidgets
  class SuggestedArticleRulesValidation < ApiValidation
    attr_accessor :conditions, :filter, :rule_operator, :position

    validates :conditions, data_type: { rules: Array },
                           array: { data_type: { rules: Hash },
                                    hash: { validatable_fields_hash: proc { |x| x.conditions_hash } } },
                           allow_blank: false
    validates :conditions, presence: true, on: :create
    validates :filter, data_type: { rules: Hash },
                       hash: { validatable_fields_hash: proc { |x| x.filter_hash } },
                       allow_blank: false
    validates :filter, presence: true, on: :create
    validates :rule_operator, data_type: { rules: Integer }, custom_inclusion: { in: HelpWidgetSuggestedArticleRule::RULE_OPERATOR.values }
    validates :position, data_type: { rules: Integer }
    validate :duplicate_filter_value, if: -> { errors.blank? && @filter && @filter[:value] }

    def conditions_hash
      {
        evaluate_on: {
          data_type: {
            rules: Integer,
            allow_blank: false
          },
          custom_inclusion: {
            in: HelpWidgetSuggestedArticleRule::EVALUATE_ON.values
          }
        },
        name: {
          data_type: {
            rules: Integer,
            allow_blank: false
          },
          custom_inclusion: {
            in: HelpWidgetSuggestedArticleRule::NAME.values
          }
        },
        operator: {
          data_type: {
            rules: Integer,
            allow_blank: false
          },
          custom_inclusion: {
            in: HelpWidgetSuggestedArticleRule::OPERATOR.values
          }
        },
        value: {
          data_type: {
            rules: String,
            allow_blank: false,
            required: true
          }
        }
      }
    end

    def filter_hash
      {
        type: {
          data_type: {
            rules: Integer,
            allow_blank: false
          },
          custom_inclusion: {
            in: HelpWidgetSuggestedArticleRule::FILTER_TYPE.values
          }
        },
        value: {
          data_type: {
            rules: Array,
            required: true
          }
        },
        order_by: {
          data_type: {
            rules: Integer,
            allow_blank: false
          },
          custom_inclusion: {
            in: HelpWidgetSuggestedArticleRule::ORDER_BY.values
          }
        }
      }
    end

    def duplicate_filter_value
      if filter[:value].size != filter[:value].uniq.size
        errors[:filter_value] << :duplicate_not_allowed
        error_options[:name] = 'filter_value'
        error_options[:list] = filter[:value].join(',')
      end
    end
  end
end

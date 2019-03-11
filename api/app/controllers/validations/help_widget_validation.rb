class HelpWidgetValidation < ApiValidation
  attr_accessor :name, :product_id, :settings, :request_params, :id
  validates :name, data_type: { rules: String }, custom_length: { maximum: HelpWidgetConstants::TEXT_FIELDS_MAX_LENGTH }, allow_nil: true
  validates :product_id, data_type: { rules: Integer }, allow_nil: true
  validates :settings, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.widget_settings_format } }, allow_nil: true, on: :update
  validates :settings, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.components_format } }, presence: true, allow_nil: false, on: :create
  validate :validate_settings, if: -> { request_params[:settings].present? && errors.blank? }
  validate :validate_create_attributes, if: -> { errors.blank? }, on: :create
  validate :validate_update_attributes, if: -> { errors.blank? && request_params[:settings].present? }, on: :update
  validate :validate_domain, if: -> { request_params[:settings].present? && request_params[:settings][:predictive_support].present? }, on: :update

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def components_format
    {
      components: {
        data_type: {
          rules: Hash
        },
        hash: { validatable_fields_hash: proc { |x| x.enabled_components_format } }
      }
    }
  end

  def components_list_format
    {
      contact_form: {
        data_type: {
          rules: 'Boolean'
        }
      },
      solution_articles: {
        data_type: {
          rules: 'Boolean'
        }
      }
    }
  end

  def widget_settings_format
    {
      message: {
        data_type: {
          rules: String
        },
        custom_length: {
          maximum: HelpWidgetConstants::TEXT_FIELDS_MAX_LENGTH
        }
      },
      button_text: {
        data_type: {
          rules: String
        },
        custom_length: {
          maximum: HelpWidgetConstants::BUTTON_TEXT_LENGTH
        }
      },
      components: {
        data_type: {
          rules: Hash
        },
        hash: {
          validatable_fields_hash: proc { enabled_components_format }
        }
      },
      contact_form: {
        data_type: {
          rules: Hash
        },
        hash: {
          validatable_fields_hash: proc { contact_form_template }
        }
      },
      appearance: {
        data_type: {
          rules: Hash
        },
        hash: {
          validatable_fields_hash: proc { widget_appearance_template }
        }
      },
      predictive_support: {
        data_type: {
          rules: Hash
        },
        hash: {
          validatable_fields_hash: proc { widget_predictive_support_template }
        }
      },
      widget_flow: {
        data_type: {
          rules: Integer
        },
        custom_inclusion: {
          in: HelpWidgetConstants::WIDGET_FLOW_TYPES.values
        }
      }
    }
  end

  def enabled_components_format
    {
      contact_form: {
        data_type: {
          rules: 'Boolean'
        }
      },
      solution_articles: {
        data_type: {
          rules: 'Boolean'
        }
      }
    }
  end

  def contact_form_template
    {
      form_type: {
        data_type: {
          rules: Integer,
          allow_nil: false
        },
        custom_inclusion: {
          in: HelpWidgetConstants::FORM_TYPES.values
        }
      },
      form_title: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: HelpWidgetConstants::TEXT_FIELDS_MAX_LENGTH
        }
      },
      form_button_text: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: HelpWidgetConstants::BUTTON_TEXT_LENGTH
        }
      },
      form_submit_message: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: HelpWidgetConstants::TEXT_FIELDS_MAX_LENGTH
        }
      },

      screenshot: {
        data_type: {
          rules: 'Boolean'
        }
      },
      attach_file: {
        data_type: {
          rules: 'Boolean'
        }
      },
      captcha: {
        data_type: {
          rules: 'Boolean'
        }
      }
    }
  end

  def widget_appearance_template
    {
      position: {
        data_type: {
          rules: Integer,
          allow_nil: true
        },
        custom_inclusion: {
          in: HelpWidgetConstants::POSITION_TYPES.values
        },
        custom_numericality: { only_integer: true, greater_than: 0 }
      },
      offset_from_bottom: {
        data_type: {
          rules: Integer,
          allow_nil: true
        },
        custom_numericality: { only_integer: true, greater_than: 0 }
      },
      offset_from_left: {
        data_type: {
          rules: Integer,
          allow_nil: true
        },
        custom_numericality: { only_integer: true, greater_than: 0 }
      },
      offset_from_right: {
        data_type: {
          rules: Integer,
          allow_nil: true
        },
        custom_numericality: { only_integer: true, greater_than: 0 }
      },
      color_schema: {
        data_type: {
          rules: Integer
        },
        custom_inclusion: {
          in: HelpWidgetConstants::COLOR_SCHEMA_TYPES.values
        },
        custom_numericality: { only_integer: true, greater_than: 0 }
      },
      gradient: {
        data_type: {
          rules: Integer
        },
        custom_numericality: { only_integer: true, greater_than: 0 },
        custom_inclusion: {
          in: HelpWidgetConstants::GRADIENT_TYPES.values
        }
      },
      pattern: {
        data_type: {
          rules: Integer
        },
        custom_numericality: { only_integer: true, greater_than: 0 },
        custom_inclusion: {
          in: HelpWidgetConstants::PATTERN_TYPES.values
        }
      },
      theme_color: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: 7
        },
        custom_format: {
          with: ApiConstants::COLOR_CODE_VALIDATOR
        }
      },
      button_color: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: 7
        },
        custom_format: {
          with: ApiConstants::COLOR_CODE_VALIDATOR
        }
      }
    }
  end

  def widget_predictive_support_template
    {
      domain_list: {
        data_type: {
          rules: Array,
          allow_nil: false
        },
        custom_length: {
          maximum: HelpWidgetConstants::MAX_DOMAIN_ALLOWED,
          message_options: { element_type: :values }
        }
      },
      welcome_message: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: HelpWidgetConstants::TEXT_FIELDS_MAX_LENGTH
        }
      },
      message: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: HelpWidgetConstants::TEXT_AREA_MAX_LENGTH
        }
      },
      success_message: {
        data_type: {
          rules: String,
          allow_nil: true
        },
        custom_length: {
          maximum: HelpWidgetConstants::TEXT_AREA_MAX_LENGTH
        }
      }
    }
  end

  def validate_domain
    domain_list = request_params[:settings][:predictive_support][:domain_list] || []
    domain_list.each do |domain|
      return errors[:domain_list] << I18n.t('help_widget.invalid_domain') unless domain.match(HelpWidgetConstants::DOMAIN_VALADITION_REGEX)
    end
  end

  def validate_create_attributes
    components_hash = request_params[:settings][:components]
    components_hash.each_key do |key|
      errors[:request_params] << I18n.t('help_widget.invalid_components', key: key) unless HelpWidgetConstants::COMPONENTS.include?(key.to_s)
    end
  end

  def validate_update_attributes
    settings = request_params[:settings]
    settings.except('message', 'button_text', 'widget_flow').each_key do |settings_key|
      settings[settings_key].each_key do |key|
        errors[key] << I18n.t('help_widget.invalid_settings', key: key) unless "HelpWidgetConstants::#{settings_key.upcase}".constantize.include?(key.to_s)
      end
    end
  end

  def validate_settings
    request_params[:settings].each_key do |key|
      errors[key] << I18n.t('help_widget.invalid_settings', key: key) unless HelpWidgetConstants::SETTINGS_FIELDS.include?(key.to_s)
    end
  end
end

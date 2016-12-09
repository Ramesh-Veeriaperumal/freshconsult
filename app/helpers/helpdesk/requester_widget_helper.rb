# encoding: utf-8
module Helpdesk::RequesterWidgetHelper

  include ContactsCompaniesHelper
  include DateHelper
  include MemcacheKeys

  COMPANY_FIELDS_DEFAULT_TYPES      = [:default_name]
  CONTACT_FIELDS_DEFAULT_TYPES      = [:default_name, :default_job_title]
  CONTACT_FIELDS_EXCLUDE_TYPES      = [:default_company_name, :default_client_manager]
  COMPANY_FIELDS_EXCLUDE_TYPES      = [:default_domains]
  WIDGET_FIELDS_MAX_COUNT           = 12
  DEFAULT_FIELDS_COUNT              = 3
  CONTACT_WIDGET_MAX_DISPLAY_COUNT  = 5
  MAX_CHAR_LENGTH                   = 230
  PHONE_NUMBER_FIELDS               = [:default_phone, :default_mobile]
  MAX_LABEL_LENGTH                  = 10
  FIELDS_INFO                       = { :contact => 
                                        { :form             => "contact_form",
                                          :disabled_fields  => ["email"],
                                          :loading_icon     => false
                                        }, 
                                        :company => 
                                          { :form             => "company_form",
                                            :disabled_fields  => ["name"],
                                            :loading_icon     => false
                                          }
                                        }

  def requester_widget_fields
    key = REQUESTER_WIDGET_FIELDS % { :account_id => current_account.id }
    MemcacheKeys.fetch(key) do
      default_requester_widget_fields | custom_requester_widget_fields
    end
  end

  def requester_widget_default_fields
    requester_widget_fields[0..2] || []
  end

  def requester_widget_custom_fields
    requester_widget_fields[3..-1] || []
  end

  def default_requester_widget_fields
    widget_fields = default_contact_fields | default_company_fields
  end

  def default_contact_fields
    contact_fields =  current_account.contact_form.contact_fields.select { |field|
      default_widget_field?(field)
    }
  end

  def contact_form_company_field
    current_account.contact_form.contact_fields.find { |field|
      field["name"] == "company_name"
    }
  end

  def default_company_fields
    company_fields =  current_account.company_form.company_fields.select { |field|
      default_widget_field?(field)
    }
  end

  def requester_widget_contact_fields
    default_contact_fields | custom_contact_fields
  end

  def requester_widget_company_fields
    default_company_fields | custom_company_fields
  end

  def requester_widget_addable_contact_fields
    ignore_fields = CONTACT_FIELDS_EXCLUDE_TYPES + CONTACT_FIELDS_DEFAULT_TYPES
    current_account.contact_form.contact_fields.reject {|field| ignore_fields.include?(field.field_type)} - requester_widget_custom_fields
  end

  def requester_widget_addable_company_fields
    ignore_fields = COMPANY_FIELDS_EXCLUDE_TYPES + COMPANY_FIELDS_DEFAULT_TYPES
    current_account.company_form.company_fields.reject {|field| ignore_fields.include?(field.field_type)} - requester_widget_custom_fields
  end

  def get_user_default_fields_count user, company
    count = 0
    requester_widget_default_fields.each do |field|
      obj = field.is_a?(ContactField) ? user : company
      if field_value(field, obj).present?
        count=count+1
      end
    end
    count
  end

  def phone_field_data_attributes user, value
    "data-contact-id='#{user.id}' data-phone-number='#{value}'"
  end

  def construct_widget_fields user, company
    html = ""
    count = get_user_default_fields_count(user, company)
    requester_widget_custom_fields.each do |field|
      obj = field.is_a?(ContactField) ? user : company
      if field_value(field, obj).present?
        html << "<div class='widget-more-content hide'>" if count == CONTACT_WIDGET_MAX_DISPLAY_COUNT
        count=count+1
        value = obj.send(field.name)
        value = format_field_value(field, value) || value
        html << "<div class='contact-append'>
          <span class='add-on field-label long_text'>
          <span class='label-name  #{ "tooltip" if (field.label.length > MAX_LABEL_LENGTH) }'
            title='#{ field.label.titleize if (field.label.length > MAX_LABEL_LENGTH) }'>
          #{field.label}</span></span><span class='label-colon'>:</span>
          <span class='field-value #{"can-make-calls" if phone_field?(field)}' #{phone_field_data_attributes(user, value) if phone_field?(field)}>#{value}</span>
        </div>"
      end
    end

    if count > CONTACT_WIDGET_MAX_DISPLAY_COUNT
      html << "</div><div class='pull-left'>
        <span class='widget-more-toggle condensed'>#{t("requester_widget_more")}</span>
      </div>"
    end
    html
  end

  def construct_requester_widget_field form_builder, object, field
    obj_name    = object_name field
    class_name  = FIELDS_INFO[obj_name][:form].clone
    class_name = 'field_maxlength '+ class_name if field.name == "address"
    enabled     = FIELDS_INFO[obj_name][:disabled_fields].exclude?(field.name)
    required    = enabled ? field.required_for_agent : false
    value       = field_value(field, object)
    placeholder = field.dom_placeholder
    args        = { :include_loading_symbol => FIELDS_INFO[obj_name][:loading_icon]}

    if obj_name == :company
      if required
        class_name = 'compare-required '+ class_name 
        required = false
      end
      if field.name == "name" && value.blank?
        required = contact_form_company_field.required_for_agent
        enabled = true
        args[:autocomplete] = true
        placeholder = I18n.t('requester_widget.search_company')
        class_name = 'company-required '+ class_name
      end
    end
    CustomFields::View::DomElement.new(form_builder, obj_name, class_name, field, field.label,
      field.dom_type, required, enabled, value, placeholder, field.bottom_note, args).construct
  end

  private

    def field_value(field, object)
      value = (object.present? && object.send(field.name).present?) ? object.send(field.name) : field.default_value
    end

    def object_name field
      field.is_a?(ContactField) ? :contact : :company
    end

    def phone_field? field
      PHONE_NUMBER_FIELDS.include?(field.field_type)
    end

    def default_widget_field? field
      (field.is_a?(ContactField) ? CONTACT_FIELDS_DEFAULT_TYPES : COMPANY_FIELDS_DEFAULT_TYPES).include?(field.field_type)
    end

    def custom_requester_widget_fields
      widget_fields = custom_contact_fields | custom_company_fields
      widget_fields.sort_by { |field| field.field_options["widget_position"] }
    end

    def custom_contact_fields
      contact_fields = current_account.contact_form.contact_fields.select { |field|
        field.field_options.present? && field.field_options.key?("widget_position")
      }
      contact_fields.sort_by { |field| field.field_options["widget_position"] }
    end

    def custom_company_fields
      company_fields = current_account.company_form.company_fields.select { |field|
        field.field_options.present? && field.field_options.key?("widget_position")
      }
      company_fields.sort_by { |field| field.field_options["widget_position"] }
    end

    def truncate_widget_field_value value
      "#{value[0..MAX_CHAR_LENGTH-1]}<span class='hidden-text hide'>#{value[MAX_CHAR_LENGTH..-1]}</span><span class='more-toggle'><i id='ficon-ellipsis' class='ficon-ellipsis'></i></span>"
    end

    def format_field_value field, value
      case field.field_type
      when :default_language
        value = I18n.name_for_locale(value)
      when :custom_dropdown
        value = CGI.unescapeHTML(value)
      end

      case field.dom_type
      when :checkbox
        value = value ? I18n.t('plain_yes') : I18n.t('plain_no')
      when :date
        value = formatted_date(value)
      when :paragraph
        value = h(value).gsub(/\n/, '<br />').html_safe
      end

      value = truncate_widget_field_value(value) if value.is_a?(String) && value.length > MAX_CHAR_LENGTH
      value
    end
end

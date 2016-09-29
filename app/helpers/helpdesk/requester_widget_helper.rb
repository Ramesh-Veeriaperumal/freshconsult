# encoding: utf-8
module Helpdesk::RequesterWidgetHelper

  include ContactsCompaniesHelper
  include DateHelper
  include MemcacheKeys

  COMPANY_FIELDS_DEFAULT_TYPES = [1]
  CONTACT_FIELDS_DEFAULT_TYPES = [1,2]
  CONTACT_FIELDS_EXCLUDE_TYPES = [7,8]
  WIDGET_FIELDS_MAX_COUNT = 7
  CONTACT_WIDGET_MAX_DISPLAY_COUNT = 5
  MAX_CHAR_LENGTH = 230
  PHONE_NUMBER_FIELDS = [4,5]
  MAX_LABEL_LENGTH = 10

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
    widget_fields = default_customer_fields | default_company_fields
  end

  def default_customer_fields
    customer_fields =  current_account.contact_form.contact_fields.select { |field|
      CONTACT_FIELDS_DEFAULT_TYPES.include?(field["field_type"])
    }
  end

  def company_field_of_contact_form
    current_account.contact_form.contact_fields.select { |field|
      field["name"] == "company_name"
    }
  end

  def default_company_fields
    company_fields =  current_account.company_form.company_fields.select { |field|
      COMPANY_FIELDS_DEFAULT_TYPES.include?(field["field_type"])
    }
  end

  def requester_widget_customer_fields
    default_customer_fields | custom_customer_fields
  end

  def requester_widget_company_fields
    default_company_fields | custom_company_fields
  end

  def requester_widget_addable_contact_fields
    ignore_fields = CONTACT_FIELDS_EXCLUDE_TYPES + CONTACT_FIELDS_DEFAULT_TYPES
    current_account.contact_form.contact_fields.select { |field|
      !ignore_fields.include?(field["field_type"])
    } - requester_widget_custom_fields
  end

  def requester_widget_addable_company_fields
    current_account.company_form.company_fields.select { |field|
      !COMPANY_FIELDS_DEFAULT_TYPES.include?(field["field_type"])
    } - requester_widget_custom_fields
  end

  def get_user_default_fields_count user
    count = 0
    requester_widget_default_fields.each do |field|
      obj = field.is_a?(ContactField) ? user : user.company
      if obj && obj.send(field.name).present?
        count=count+1
      end
    end
    count
  end

  def phone_field_data_attributes user, value
    return "data-contact-id='#{user.id}' data-phone-number='#{value}'"
  end

  def construct_widget_fields user
    html = ""
    count = get_user_default_fields_count user
    requester_widget_custom_fields.each do |field|
      obj = field.is_a?(ContactField) ? user : user.company
      if obj && obj.respond_to?(field.name) && obj.send(field.name).present?
        html << "<div class='widget-more-content hide'>" if count == CONTACT_WIDGET_MAX_DISPLAY_COUNT
        count=count+1
        value = obj.send(field.name)
        value = format_field_value(field, value) || value
        html << "<div class='contact-append #{"can-make-calls" if PHONE_NUMBER_FIELDS.include?(field["field_type"]) && field.is_a?(ContactField)}' #{phone_field_data_attributes(user, value) if PHONE_NUMBER_FIELDS.include?(field["field_type"]) && field.is_a?(ContactField)}>
          <span class='add-on field-label'>
          <span class='label-name  #{ "tooltip" if (field.label.length > MAX_LABEL_LENGTH) }'
            title='#{ field.label if (field.label.length > MAX_LABEL_LENGTH) }'>
          #{field.label}</span>:</span>
          <span class='field-value'>#{value}</span>
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

  def construct_requester_widget_field form_builder, requester, field
    args = {}
    field_value = field.default_value
    placeholder = field.dom_placeholder
    disabled = false
    if field.class == ContactField
      field_value = (field_value = requester.send(field.name)).blank? ? field.default_value : field_value
      obj = :contact
      required = field.required_for_agent
      class_name = "contact_form"
      disabled = ["email"].exclude?(field.name)
    else
      field_value = (field_value = requester.company.send(field.name)).blank? ?
        field.default_value : field_value if requester.company.present?
      obj = :company
      # to be enabled if company name edit is enabled
      #required = field.name == "name" ? company_field_of_contact_form[0].required_for_agent : field.required_for_agent
      required = field.required_for_agent # to be removed if company name edit is enabled
      class_name = "company_form"
      disabled = true
      if field.name == "name"
        disabled = false # to be removed if company name edit is enabled
        required = false # to be removed if company name edit is enabled
        args[:autocomplete] = true
        placeholder = I18n.t('requester_widget.search_company')
      end
      args[:include_loading_symbol] = true
    end

    CustomFields::View::DomElement.new(form_builder, obj, class_name, field, field.label,
      field.dom_type, required, disabled, field_value, placeholder,
      field.bottom_note, args).construct
  end

  private

    def custom_requester_widget_fields
      widget_fields = custom_customer_fields | custom_company_fields
      widget_fields.sort_by { |field| field["field_options"]["widget_position"] }
    end

    def custom_customer_fields
      customer_fields = current_account.contact_form.contact_fields.select { |field|
        field["field_options"].present? && field["field_options"].key?("widget_position")
      }
      customer_fields.sort_by { |field| field["field_options"]["widget_position"] }
    end

    def custom_company_fields
      company_fields = current_account.company_form.company_fields.select { |field|
        field["field_options"].present? && field["field_options"].key?("widget_position")
      }
      company_fields.sort_by { |field| field["field_options"]["widget_position"] }
    end

    def truncate_widget_field_value value
      "#{value[0..MAX_CHAR_LENGTH]}
      <span class='hidden-text hide'>#{value[MAX_CHAR_LENGTH..-1]}</span>
      <span class='more-toggle'><i id='ficon-ellipsis' class='ficon-ellipsis'></i></span>"
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

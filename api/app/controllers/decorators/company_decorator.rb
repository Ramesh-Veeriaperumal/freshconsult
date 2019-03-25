class CompanyDecorator < ApiDecorator
  include Helpdesk::RequesterWidgetHelper

  delegate :id, :name, :description, :note, :users, :avatar, :health_score,
           :account_tier, :industry, :tam_fields, to: :record
  delegate :tam_default_fields_enabled?, to: 'Account.current'

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
    @sla_policies = options[:sla]
  end

  def custom_fields
    # @name_mapping will be nil for READ requests, hence it will computed for the first
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = format_date(v) } if @name_mapping.present?
    custom_fields_hash
  end

  def renewal_date
    format_date(record.renewal_date, true)
  end

  def domains
    record.domains.nil? ? [] : record.domains.split(',')
  end

  def sla_policies
    @sla_policies.map { |item| SlaPolicyDecorator.new(item).private_hash }
  end

  def avatar_hash
    return nil unless avatar.present?
    AttachmentDecorator.new(avatar).to_hash
  end

  def to_hash
    response = {
      id: id,
      name: name,
      description: description,
      note: note,
      domains: domains,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      custom_fields: custom_fields,
      avatar: avatar_hash
    }
    response.merge!(tam_fields)
    response
  end

  def to_search_hash
    user_count = users.count
    {
      id: id,
      name: name,
      description: description,
      note: note,
      domains: domains,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      custom_fields: custom_fields,
      user_count: user_count
    }
  end

  def utc_format(value)
    value.respond_to?(:utc) ? value.utc : value
  end

  def company_hash
    construct_hash(requester_widget_company_fields, record)
  end

  private

    def construct_hash(req_widget_fields, obj)
      default_fields = req_widget_fields.select(&:default_field?)
      custom_fields = req_widget_fields.reject(&:default_field?)
      ret_hash = widget_fields_hash(obj, default_fields)
      ret_hash[:custom_fields] = widget_fields_hash(obj, custom_fields, true) if custom_fields.present?
      ret_hash[:id] = obj.id
      ret_hash
    end

    def widget_fields_hash(obj, fields, name_mapping = false)
      return fields.inject({}) { |a, e| a.merge(e.name => obj.safe_send(e.name)) } unless name_mapping
      fields.inject({}) { |a, e| a.merge(CustomFieldDecorator.display_name(e.name) => format_date(obj.safe_send(e.name))) }
    end

    def current_account
      Account.current
    end
end

class DashboardDelegator < BaseDelegator
  include ::Dashboard::UtilMethods

  validate :validate_product, if: -> { @product_id }
  validate :validate_group, if: -> { @group_id }
  validate :validate_status, if: -> { @status }
  validate :validate_responder, if: -> { @responder_id }
  validate :validate_filter, if: -> { @group_id || @product_id }

  def initialize(_item, options)
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def validate_group
    group_ids = build_agent_groups
    unless group_ids.present? && @group_id.all? { |g_id| group_ids.include?(g_id) }
      errors[:group_id] << :inaccessible_value
    end
  end

  def validate_product
    product_ids = Account.current.products_from_cache.collect(&:id)
    unless @product_id.all? { |p_id| product_ids.include?(p_id) }
      errors[:product_id] << :inaccessible_value
    end
  end

  def validate_status
    statuses = statuses_list_from_cache.keys
    unless @status.all? { |st| statuses.include?(st) }
      errors[:status] << :"is invalid"
    end
  end

  def validate_responder
    responders = Account.current.agents_details_from_cache.collect(&:id)
    unless responders.present? && @responder_id.all? { |resp| responders.include?(resp) }
      errors[:responder_id] << :"is invalid"
    end
  end

  def validate_filter
    if @dashboard_type.include?('agent')
      errors[:group_id] << :inaccessible_value if @group_id
      errors[:product_id] << :inaccessible_value if @product_id
    end
  end

  def statuses_list_from_cache
    statuses = Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
    statuses.delete_if { |st| [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(st) }
  end

  private

    def build_agent_groups
      scope = User.current.agent.ticket_permission_token
      case scope
      when :all_tickets
        Account.current.groups_from_cache.collect(&:id)
      when :group_tickets
        User.current.agent_groups.pluck(:group_id)
      else
        []
      end
    end
end

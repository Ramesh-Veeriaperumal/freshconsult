module UsageMetrics::EstateFeatures
  include UsageMetrics::GardenFeatures

  def round_robin(args)
    args[:account].groups_from_cache.any?{ |group| group.ticket_assign_type > 0 }
  end

  def shared_ownership_toggle(args)
    args[:account].has_feature? :shared_ownership
  end

  def customer_slas(args)
    args[:account].sla_policies.rule_based.active.exists?
  end

  def multi_product(args)
    args[:account].products_from_cache.present?
  end

  def dynamic_sections(args)
    args[:account].ticket_fields_from_cache.any? { |field| 
      field.field_options['section_present'] if field.field_options 
    }
  end

  def layout_customization(args)
    args[:account].portal_pages.exists?
  end

  def custom_roles(args)
    args[:account].roles_from_cache.any?{ |role| role.default_role == false }
  end

  def auto_ticket_export(args)
    args[:account].scheduled_ticket_exports_from_cache.present?
  end

  def custom_dashboard(args)
    args[:account].dashboards.exists?
  end

  def multiple_user_companies(args)
    args[:account].user_companies.has_multiple_companies?
  end

  def multiple_business_hours(args)
    args[:account].groups.has_different_business_hours?
  end

  def segments(args)
    args[:account].contact_filters.exists?
  end
end
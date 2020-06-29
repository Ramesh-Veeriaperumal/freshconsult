module AuditLog::Translators::SolutionFolder
  include AuditLogConstants

  def readable_solution_folder_changes(model_changes)
    model_changes.each do |key, value|
      case key
      when :visibility
        model_changes[key].map! { |id| folder_property_tranlate('visible_to', VISIBILITY_NAMES_BY_ID[id]) }
      when :article_order
        model_changes[key].map! { |id| folder_property_tranlate('ordering', ORDERING_NAMES_BY_ID[id]) }
      else
        next
      end
    end
    model_changes
  end

  # translate
  def folder_property_tranlate(property, type)
    I18n.t("admin.audit_log.solution_folder.#{property}.#{type}")
  end
end

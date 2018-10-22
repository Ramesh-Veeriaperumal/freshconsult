module DiffHelper
  METHODS = ['added', 'modified', 'deleted', 'conflict']
  def compare_ids(diff, diff_data)
    diff_data = {}
    generated_diff_ids = {}
    data_diff_ids = {}
    METHODS.each do |method_name|
      generated_diff_ids[method_name] ||= {}
      diff.each do |association, data|
        next if association == "agents"
        if association == "ticket_fields"
          generated_diff_ids[method_name][association] = data.map { |item| item['id'] if (item['action'] == method_name && item['model'] == "Helpdesk::TicketField")}.compact 
        else
          generated_diff_ids[method_name][association] = data.map { |item| item['id'] if item['action'] == method_name }.compact
        end
      end
      data_diff_ids[method_name] ||= {}
      diff_data.each do |association, data|
        association = association_mapping(association)
        if (method_name == 'modified' && (association == "ticket_fields" || association == "va_rules"))
          (data_diff_ids[method_name][association] ||= []) << data.map { |item| item[:id].to_i if item[:status] == method_name.to_sym && !(item[:changes].count == 1 && item[:changes].first[:key] =~ /(.*)\/position/) }.compact
        else
          (data_diff_ids[method_name][association] ||= []) << data.map { |item| item[:id].to_i if item[:status] == method_name.to_sym }.compact
        end
      end
    end

    data_diff_ids.each do |method_name, changes|
      diff_data[method_name] ||= {}
      data_diff_ids[method_name].each do |association, values|
        diff_data[method_name][association] ||= []
        diff_data[method_name][association] << [generated_diff_ids[method_name][association].uniq.sort, data_diff_ids[method_name][association].flatten.uniq.sort]
      end
    end
  end

  def association_mapping(association)
    association = 'va_rules' if association.in? ['all_va_rules', 'all_supervisor_rules', 'all_observer_rules', 'scn_automations']
    association = 'password_policies' if association.in? ['contact_password_policy', 'agent_password_policy']
    association
  end
end

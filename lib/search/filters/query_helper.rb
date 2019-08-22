# Query/Filter generation helpers
# Can be reused for fetching documents too
module Search::Filters::QueryHelper
  extend ActiveSupport::Concern
  include Search::Filters::TicketsHelper

  private

    ######### Cases implemented ########
    # responder_id  : terms with hack  #
    # group_id      : terms with hack  #
    # created_at    : range            #
    # due_by        : range            #
    # rest          : terms            #
    ####################################

    def es_query(conditions, neg_conditions, with_permissible = true)
      condition_block = {
        should:   [],
        must:     [],
        must_not: []
      }
      # Hack for handling permissible as used in tickets
      #with_permissible will be false when queried from admin->tag as we dont need permisible there.
      if Account.current.shared_ownership_enabled?
        condition_block[:must].push(shared_ownership_permissible_filter) if with_permissible and User.current.agent? and User.current.restricted?
        construct_conditions_shared_ownership(condition_block[:must], conditions)
      else
        condition_block[:must].push(permissible_filter) if with_permissible and User.current.agent? and User.current.restricted?
        construct_conditions(condition_block[:must], conditions)
      end
      condition_block[:must].push(account_id_filter)
      construct_conditions(condition_block[:must_not], neg_conditions)
      filtered_query(nil, bool_filter(condition_block))
    end

    def permissible_filter
      ({
        :group_tickets      =>  bool_filter(:should => [
                                                        group_id_es_filter('group_id', ['0']), 
                                                        term_filter('responder_id', User.current.id.to_s)
                                                        ]),
        :assigned_tickets   =>  term_filter('responder_id', User.current.id.to_s)
      })[Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]]
    end

    def shared_ownership_permissible_filter
      ({
        :group_tickets    => bool_filter(:should => [
                                                    group_id_es_filter('group_id', ['0']),
                                                    group_id_es_filter('internal_group_id', ['0']),
                                                    term_filter('responder_id', User.current.id.to_s),
                                                    term_filter('internal_agent_id', User.current.id.to_s)
                                                    ]),
        :assigned_tickets => bool_filter(:should => [
                                                    term_filter('responder_id', User.current.id.to_s),
                                                    term_filter('internal_agent_id', User.current.id.to_s)
                                                    ])
        })[Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]]
    end

    # Loop and construct ES conditions from WF filter conditions
    def construct_conditions_shared_ownership(es_wrapper, wf_conditions)
      unassigned_in_any_agent = false
      wf_conditions.each do |field|
        # Doing gsub as flexifields are flat now.
        cond_field = (COLUMN_MAPPING[field['condition']].presence || field['condition'].to_s).gsub('flexifields.','')
        field_values = field['value'].is_a?(Array) ? field['value'] : field['value'].to_s.split(',')

        # Hack for any agent filter has unassigned and has value for any group filter
        # Need to do (Agent = Unassigned & Group = X) OR (I.Agent = Unassigned  & I.Group = X)
        any_group_condition = wf_conditions.select { |cond| cond["condition"] == "any_group_id" }
        any_agent_condition = wf_conditions.select { |cond| cond["condition"] == "any_agent_id" }
        any_group_values = (any_group_condition.first)["value"].to_s.split(",") unless any_group_condition.empty?

        if cond_field.eql?('any_agent_id') and field_values.include?('-1') and !any_group_condition.empty?
          unassigned_in_any_agent = true
          field_values.delete('-1')
          es_wrapper.push(handle_field_ext("unassigned_any_agent", field_values, any_group_values))
          next if field_values.empty?
        else
          next if cond_field.eql?('any_group_id') and unassigned_in_any_agent
          es_wrapper.push(handle_field(cond_field, field_values)) if cond_field.present?
        end
      end
    end

    # For generically handling other fields
    def handle_field(field_name, values)
      safe_send("#{field_name}_es_filter", field_name, values) rescue missing_es_filter(field_name, values)
    end

    # for handling a specific case where the method needs two args
    def handle_field_ext(field_name, field_values, group_values)
      safe_send("#{field_name}_es_filter", field_name, field_values, group_values) rescue missing_es_filter(field_name, field_values)
    end
end

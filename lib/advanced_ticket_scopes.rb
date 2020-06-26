module AdvancedTicketScopes
  ADVANCED_READ_PERMISSION_METHOD = 'has_read_ticket_permission?'.freeze
  TICKET_PERMISSION_METHOD = 'has_ticket_permission?'.freeze # equivalent to write access

  TICKET_ACTIONS = %i[update_properties spam unspam restore watch unwatch].freeze

  NOTE_ACTIONS = %i[reply forward reply_to_forward facebook_reply reply_template tweet ecommerce_reply forward_template latest_note_forward_template execute_scenario broadcast].freeze

  COMMON_CONTROLLER_ACTIONS = %i[create update destroy].freeze

  # This is to handle cases to disallow create,update and destory actions in todo, time_entries etc
  ALLOWED_COMMON_ACTIONS_TO_CONTROLLER_MAPPING = {
                                                   create: %w[tickets conversations],
                                                   update: %w[conversations],
                                                   destroy: %w[conversations]
                                                 }.freeze

  READ_PERMISSION_DISALLOWED_ACTIONS = TICKET_ACTIONS + NOTE_ACTIONS

  def helpdesk_ticket_permission?(user, ticket, note = nil)
    if note.present?
      # for private note it should be has_read_ticket_permission i.e both read and write access groups
      # for public note it should be only write_access_groups is allowed
      # for create note the user is not associated with note at this point of check
      # for reply_to_forward is also a private note type but we are not allowing it
      # Only note create, update, destroy will be having note object rest of actions will have nil for note in current code flow
      (advanced_scope_enabled? && note.private? && !note.reply_to_forward? && (create? || note_created_by_agent?(note))) ? user.safe_send(ADVANCED_READ_PERMISSION_METHOD, ticket) : user.safe_send(TICKET_PERMISSION_METHOD, ticket)
    else
      (advanced_scope_enabled? && allowed_action_under_read_access?) ? user.safe_send(ADVANCED_READ_PERMISSION_METHOD, ticket) : user.safe_send(TICKET_PERMISSION_METHOD, ticket)
    end
  end

  # This method is for the ticket decorator
  def agent_has_write_access?(ticket, agent_group_ids = nil)
    collab_app_request? || (User.current.present? && User.current.has_ticket_permission?(ticket, agent_group_ids))
  end

  private

    # For update, destroy and create we need to handle controller wise based on restriction due to common naming.
    def allowed_action_under_read_access?
      if READ_PERMISSION_DISALLOWED_ACTIONS.include?(action)
        return false
      elsif COMMON_CONTROLLER_ACTIONS.include?(action)
        return ALLOWED_COMMON_ACTIONS_TO_CONTROLLER_MAPPING[action].include?(controller_name) ? true : false
      end

      true
    end

    def advanced_scope_enabled?
      Account.current.advanced_ticket_scopes_enabled?
    end

    def note_created_by_agent?(note)
      User.current.try(:agent?) && (User.current.id == note.user_id)
    end

    def collab_app_request?
      User.current.nil? && app_current?
    end

    def set_all_agent_groups_permission
      User.current.access_all_agent_groups = true if advanced_scope_enabled?
    end
end

module Helpdesk::Permission
  module Attachment
    ATTACHMENTS_PERMISSIONS = [
      ['Helpdesk::Ticket',                 :edit_ticket_properties,  true],
      ['Helpdesk::Note',                   :edit_note,               true],
      ['Mobihelp::TicketInfo',             :edit_ticket_properties,  true],
      ['Helpdesk::ArchiveTicket' ,         :edit_ticket_properties,  true],
      ['Helpdesk::ArchiveNote',            :edit_note,               true],
      ['Solution::Article',                :publish_solution,        true],
      ['Solution::Draft',                  :publish_solution,        false],
      ['Post',                             :edit_topic,              true],
    # ['Admin::CannedResponses::Response', :manage_canned_responses, true], 
    #uncomment canned response and remove account after moving canned response attachments to attachments table
      ['Account',                          :manage_account,          false],
      ['Portal',                           :view_admin,              false],
      ['Freshfone::Call',                  :edit_ticket_properties,  true],  #check
      ['DataExport',                       nil,                      false],
      ['UserDraft',                        nil,                      false],
      ['Helpdesk::TicketTemplate' ,        :manage_ticket_templates, true]
    ]

    ATTACHMENTS_EDIT_PRIVILEGES  = Hash[*ATTACHMENTS_PERMISSIONS.map {|a| [a[0], a[1]] }.flatten ]
    CHECK_USER_OWNED             = Hash[*ATTACHMENTS_PERMISSIONS.map {|a| [a[0], a[2]] }.flatten ]

    def visible_to_me?
      obj = owner_type.tableize.singularize.gsub('/','_')
      respond_to?("can_view_#{obj}?") ? send("can_view_#{obj}?") : true
    end

    def can_be_deleted_by_me?
      return true if CHECK_USER_OWNED[owner_type] && user_owned_obj?
      visible_to_me? && check_privilege(ATTACHMENTS_EDIT_PRIVILEGES[owner_type])
    end

    def can_view_helpdesk_ticket?(ticket = owner_object)
      return false unless ::User.current
      ::User.current.agent? ? ::User.current.has_ticket_permission?(ticket) : ::User.current.has_customer_ticket_permission?(ticket)
    end

    def can_view_helpdesk_note?
      return false if ::User.current.customer? && owner_object.private?
      can_view_helpdesk_ticket? owner_object.notable
    end

    def can_view_mobihelp_ticket_info?
      can_view_helpdesk_ticket?(owner_object.ticket)
    end

    def can_view_solution_article?
      return can_view_solution_draft? unless owner_object.published?
      owner_object.solution_folder_meta.visible?(::User.current)
    end

    def can_view_solution_draft?
      ::User.current && ::User.current.privilege?(:view_solutions)
    end

    def can_view_post?
      owner_object.forum.visible?(::User.current)
    end

    def can_view_freshfone_call?
      ticket = owner_object.notable.respond_to?(:notable) ? owner_object.notable.notable : owner_object.notable
      can_view_helpdesk_ticket? ticket
    end

    def can_view_data_export?
      user_owned_obj? || check_privilege(:manage_account)
    end

    def can_view_user_draft?
      ::User.current && (owner_id == ::User.current.id)
    end

    def can_view_helpdesk_ticket_template?
      check_privilege(:manage_ticket_templates) || owner_object.visible_to_me?
    end

    alias_method :can_view_helpdesk_archive_ticket?, :can_view_helpdesk_ticket?
    alias_method :can_view_helpdesk_archive_note?, :can_view_helpdesk_note?

    protected

      def owner_type
        @owner_type ||= self.respond_to?(:droppable_type) ? self.droppable_type : self.attachable_type
      end

      def owner_object
        @owner_object ||= self.respond_to?(:droppable_type) ? self.droppable : self.attachable
      end

      def owner_id
        @owner_id ||= self.respond_to?(:droppable_type) ? self.droppable_id : self.attachable_id
      end

      def check_privilege(priv = nil)
        return true unless priv
        ::User.current && ::User.current.privilege?(priv)
      end

      def user_owned_obj?
        return false unless ::User.current
        case owner_type
        when 'Mobihelp::TicketInfo'
          return ::User.current.owns_object?(owner_object.ticket)
        when 'Helpdesk::TicketTemplate'
          return owner_object.visible_to_only_me?
        else            
          return ::User.current.owns_object?(owner_object)
        end
      end
  end
end

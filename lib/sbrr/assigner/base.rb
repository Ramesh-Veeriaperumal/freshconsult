module SBRR
  module Assigner
    class Base #have to re-implement with EVAL and lua scripts
      
      attr_reader :new_ticket, :user, :current_ticket

      def initialize _ticket, options={}
        @current_ticket = _ticket
        @group = options[:group]
        @user = options[:user]
      end

      def old_ticket
        @old_ticket ||= @current_ticket.ticket_was @current_ticket.model_changes, @current_ticket.sbrr_state_attributes, TicketConstants::SKILL_BASED_TICKET_ATTRIBUTES if @current_ticket
      end

      def new_ticket
        @new_ticket ||= @current_ticket.ticket_is @current_ticket.model_changes, @current_ticket.sbrr_state_attributes, TicketConstants::SKILL_BASED_TICKET_ATTRIBUTES if @current_ticket
      end

      def assign
        _can_assign = can_assign?
        if _can_assign
          _do_assign, _assigned = do_assign
        end
        SBRR.log "#{self.class.name} #{{:can_assign => _can_assign, :do_assign => _do_assign, :assigned => _assigned}.inspect}" 
        {:can_assign => _can_assign, :do_assign => _do_assign, :assigned => _assigned}
      end

      private

        def skill
          ticket.skill
        end

        def group
          @group || ticket.group
        end

        def user
          @user || ticket.responder
        end

        def account_id
          ticket.account_id
        end

        def group_id
          ticket.group_id
        end

        def skill_id
          ticket.skill_id
        end

    end
  end
end

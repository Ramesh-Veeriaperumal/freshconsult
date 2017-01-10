module SBRR
  module Assigner
    class Base #have to re-implement with EVAL and lua scripts
      
      attr_reader :new_ticket, :user

      def initialize _ticket, options={}
        @new_ticket = _ticket
        @group = options[:group]
        @user = options[:user]
      end

      def old_ticket
        @old_ticket ||= @new_ticket.ticket_was @new_ticket.model_changes
      end

      def assign
        _can_assign = can_assign?
        if _can_assign
          _do_assign = do_assign
        end
        SBRR.log "#{self.class.name} #{{:can_assign => _can_assign, :do_assign => _do_assign}.inspect}" 
        {:can_assign => _can_assign, :do_assign => _do_assign}
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
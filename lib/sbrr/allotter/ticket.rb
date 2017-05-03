module SBRR
  module Allotter
    class Ticket

      attr_reader :user, :group

      def initialize _user, _group = nil
        @user = _user
        @group = _group
      end

      def allot
        set_as_sbrr_fresh_user
        SBRR.log "Ticket Allotter alloting tickets for user #{user.id}"
        groups.each do |_group|
          begin
            is_assigned = SBRR::Assigner::Ticket.new(nil, :user => user, :group => _group).assign
          end while is_assigned[:do_assign] 
        end
      end

      def set_as_sbrr_fresh_user
        @user.sbrr_fresh_user = true
      end

      private

        def groups
          groups ||= if group
            [group]
          else
            user.groups.skill_based_round_robin_enabled
          end
        end
    end
  end
end
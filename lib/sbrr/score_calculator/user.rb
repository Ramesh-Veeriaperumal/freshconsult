module SBRR
  module ScoreCalculator

    class User < Base
      
      attr_reader :user_skill, :group, :operation, :user
      attr_accessor :old_score

      CAPPING_LIMIT_NO_OF_DIGITS  = 1
      SKILL_RANK_NO_OF_DIGITS     = 2
      TICKETS_COUNT_NO_OF_DIGITS  = 3
      TIMESTAMP_NO_OF_DIGITS      = 10

      CAPPING_LIMIT_DIGITS  = 0..0
      SKILL_RANK_DIGITS     = 1..2
      TICKETS_COUNT_DIGITS  = 3..5
      TIMESTAMP_DIGITS      = 6..15 #support until year 2286

      TOTAL_NO_OF_DIGITS    = 16

      MAX_SKILL_RANK    = 99
      MAX_TICKETS_COUNT = 999

      def initialize _group, _old_score = nil
        @group     = _group #group will contain the config for score
        @old_score = "%0#{TOTAL_NO_OF_DIGITS}d" % _old_score.to_i if _old_score.present? #unable to do this at one place
      end

      def score _user, _skill_id, _operation, _old_score = nil
        @user      = _user
        @operation = _operation
        @old_score = "%0#{TOTAL_NO_OF_DIGITS}d" % _old_score.to_i if _old_score.present? #unable to do this at one place
        
        "%0#{CAPPING_LIMIT_NO_OF_DIGITS}d" % capping_limit_reached +
          "%0#{SKILL_RANK_NO_OF_DIGITS}d" % user_skill_rank(_skill_id) +
            "%0#{TICKETS_COUNT_NO_OF_DIGITS}d" % operated_assigned_tickets_in_group +
              "%0#{TIMESTAMP_NO_OF_DIGITS}d" % timestamp
      end

      def capping_limit_reached
        @capping_limit_reached ||= (operated_assigned_tickets_in_group >= group.capping_limit) ? 1 : 0
      end

      def user_skill_rank(_skill_id)
        if old_score.present?
          old_user_skill_rank
        else
          _user_skill = user.user_skills.find{|user_skill| user_skill.skill_id == _skill_id} # doing array.find
          rank        = _user_skill ? _user_skill.rank : 0
          (rank <= MAX_SKILL_RANK) ? rank : MAX_SKILL_RANK
        end
      end

      def operated_assigned_tickets_in_group
        @operated_assigned_tickets_in_group ||= begin
          count = perform @operation, assigned_tickets_in_group
          (count <= MAX_TICKETS_COUNT) ? count : MAX_TICKETS_COUNT
        end
      end

      def assigned_tickets_in_group
        @assigned_tickets_in_group ||= if old_score.present?
          old_assigned_tickets_in_group
        else
          count = assigned_tickets_count_from_db
          (count <= MAX_TICKETS_COUNT) ? count : MAX_TICKETS_COUNT
        end
      end

      def timestamp
        @timestamp ||= if old_score.present?
          @operation == :incr ? Time.now.to_i : old_timestamp.to_i
        else
          Time.now.to_i
        end
      end

      def old_assigned_tickets_in_group
        @old_score[TICKETS_COUNT_DIGITS].to_i
      end

      private

        def assigned_tickets_count_from_db
          status_ids   = Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.current)
          ticket_count = Sharding.run_on_slave { 
                          group.tickets.visible.agent_tickets(status_ids, user.id).count 
                         }
        end

        def old_capping_limit_reached
          @old_score[CAPPING_LIMIT_DIGITS].to_i
        end

        def old_user_skill_rank
          @old_score[SKILL_RANK_DIGITS].to_i
        end

        def old_timestamp
          @old_score[TIMESTAMP_DIGITS].to_i
        end

        def perform operation, count
          case operation
          when :incr
            count += 1
          when :decr
            count -= 1 unless count == 0
          end
          count
        end

    end

  end
end

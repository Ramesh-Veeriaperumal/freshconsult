module SBRR
  module QueueAggregator
    class Base

      attr_reader :user, :group, :skill

      def initialize(_user = nil, options = {})
        @user  = _user
        @group = options[:group]
        @skill = options[:skill]
        @skills= options[:skills]
      end

      def relevant_queues
        queues = []
        groups.each do |_group|
          _score_calculator = score_calculator _group
          skills.each do |_skill|
            queues << queue(_group.id, _skill.id, _score_calculator)
          end
        end
        queues
      end

      private

        def groups
          @groups ||= if group
            [ group ]
          elsif user
            user.groups.skill_based_round_robin_enabled.select("groups.id, capping_limit")
          else
            Account.current.groups.skill_based_round_robin_enabled.select("id, capping_limit")
          end
        end

        def skills
          @skills ||= if skill
            [ skill ]
          elsif user
            user.skills.select("skills.id")
          else
            Account.current.skills.select("id")
          end
        end

        def account_id
          Account.current.id
        end

    end
  end
end

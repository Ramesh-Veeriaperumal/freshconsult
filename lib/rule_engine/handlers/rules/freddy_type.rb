module RuleEngine
  module Handlers
    class Rules::FreddyType < RuleHandler
      include Redis::AutomationRuleRedis
      def matches(evaluate_on)
        safe_send(condition.operator + '_' + value, evaluate_on)
      end

      def is_thank_you_note(evaluate_on)
        result = evaluate_condition(evaluate_on)
        rule_id = Thread.current[:automation_log_vars][:rule_id]
        Thread.current[:thank_you_note] = { rule_id: rule_id, result: result } if result && rule_id.present?
        result
      end

      def is_not_thank_you_note(evaluate_on)
        result = evaluate_condition(evaluate_on)
        rule_id = Thread.current[:automation_log_vars][:rule_id]
        Thread.current[:thank_you_note] = { rule_id: rule_id, result: result } if !result && rule_id.present?
        !result
      end

      private

        def evaluate(response)
          confidence = get_automation_redis_key(THANK_YOU_NOTE_CONFIDENCE)
          confidence = confidence.present? ? confidence.to_i : FreddySkillsConfig[:detect_thank_you_note][:confidence_threshold]
          response.present? && response[:reopen].zero? && response[:confidence] > confidence
        end

        def evaluate_condition(evaluate_on)
          note = evaluate_on.thank_you_note
          response = note.schema_less_note.thank_you_note if note.schema_less_note.thank_you_note.present?
          evaluate(response)
        end
    end
  end
end

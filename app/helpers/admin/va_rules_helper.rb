module Admin::VaRulesHelper
	def event_placeholders
		{:events => [['{{triggered_event}}', 'Triggered Event', 'Details about the event that triggered the rule', 'triggered_event']]}
	end
end
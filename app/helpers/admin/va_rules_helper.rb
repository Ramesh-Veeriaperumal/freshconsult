module Admin::VaRulesHelper
	def event_placeholders
		[['{{triggered_event}}', 'Triggered Event', 'Details about the event that triggered the rule', 'triggered_event']]
	end
end
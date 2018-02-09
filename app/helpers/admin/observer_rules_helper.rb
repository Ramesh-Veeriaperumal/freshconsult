module Admin::ObserverRulesHelper
	def event_placeholders
		{:events => [['{{triggered_event}}', t('placeholder.triggered_event'), t('placeholder.tooltip.triggered_event'), 'triggered_event']]}
	end
end
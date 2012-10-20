class Sphinx::TicketDelta < ThinkingSphinx::Deltas::DefaultDelta

  def index(model, instance = nil)
  	RAILS_DEFAULT_LOGGER.debug "$$$$$$$$$$$$$$$$$ Came for index -- updates Enabled #{ThinkingSphinx.updates_enabled?} --- deltas enabled #{ThinkingSphinx.deltas_enabled?}"
  	return true unless ThinkingSphinx.updates_enabled?
    RAILS_DEFAULT_LOGGER.debug "$$$$$$$$$$$$$$$$$ Updates Enabled"
  	return true if instance && !toggled(instance) 
  	RAILS_DEFAULT_LOGGER.debug "$$$$$$$$$$$$$$$$$ Toggled"
  	if instance 
  		RAILS_DEFAULT_LOGGER.debug "$$$$$$$$$$$$$$$$$ Job enqued"
  		Resque.enqueue(Sphinx::FlagAsDeleted, { :document_id => instance.sphinx_document_id,
  			:model_name => "Helpdesk::Ticket"}) 
  	end
  	ThinkingSphinx.updates_enabled = true
  end

end
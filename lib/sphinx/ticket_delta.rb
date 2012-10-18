class Sphinx::TicketDelta < ThinkingSphinx::Deltas::DefaultDelta

  def index(model, instance = nil)
  	return true if instance && !toggled(instance) && instance.new_record?
  	Resque.enqueue(Sphinx::FlagAsDeleted, { :document_id => instance.sphinx_document_id,
  		:model_name => "Helpdesk::Ticket"}) if instance 
  end

end
class FreshdeskSphinxDelta < ThinkingSphinx::Deltas::DefaultDelta

  def index(model, instance = nil)
  	return true if instance && !toggled(instance)
  	delete_from_core(model, instance) if instance 
  end

end
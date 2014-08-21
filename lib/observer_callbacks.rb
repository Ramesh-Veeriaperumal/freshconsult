module ObserverCallbacks
  # Calls define_model_callbacks and notify observers when called
  def define_model_callbacks_for_observers(*args)
    types = Array.wrap(args.extract_options![:only] || [:before, :around, :after])
 
    callbacks = define_model_callbacks(*args)
 
    callbacks.each do |callback|
      types.each do |filter|
        set_callback(callback, filter) do
          notify_observers :"#{filter}_#{callback}"
          true
        end
      end
    end
  end
end
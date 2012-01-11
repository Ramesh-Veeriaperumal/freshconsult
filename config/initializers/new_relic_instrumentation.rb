require 'new_relic/agent/method_tracer.rb'

if defined?(ThinkingSphinx::Search)
  ThinkingSphinx::Search.class_eval do
    include NewRelic::Agent::MethodTracer
    add_method_tracer :search
    add_method_tracer :populate
  end

  Riddle::Client.class_eval do
    include NewRelic::Agent::MethodTracer
    add_method_tracer :query
  end
  
  SearchController.class_eval do
    include NewRelic::Agent::MethodTracer
    add_method_tracer :search
  end
  
end
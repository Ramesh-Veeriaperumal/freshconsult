require 'new_relic/agent/method_tracer.rb'



if defined?(ThinkingSphinx::Search)
  ThinkingSphinx::Search.class_eval do
   include NewRelic::Agent::MethodTracer
   add_method_tracer :initialize
   add_method_tracer :results
   add_method_tracer :populate
   add_method_tracer :search
  end

  Riddle::Client.class_eval do
   include NewRelic::Agent::MethodTracer
   add_method_tracer :query
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect 'wf/filter/:action', :controller => 'wf/filter'
  map.connect 'wf/calendar/:action', :controller => 'wf/calendar'
  map.connect 'wf/exporter/:action', :controller => 'wf/exporter'
  map.connect 'my_views', :controller => 'wf/filter', :action => 'index'
end

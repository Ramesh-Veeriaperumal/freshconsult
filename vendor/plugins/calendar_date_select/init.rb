%w[calendar_date_select includes_helper].each { |file| 
  require File.join( File.dirname(__FILE__), "lib",file) 
}

ActionView::Helpers::FormHelper.send(:include, CalendarDateSelect::FormHelper)
ActionView::Base.send(:include, CalendarDateSelect::FormHelper)
ActionView::Base.send(:include, CalendarDateSelect::IncludesHelper)

# TODO-RAILS3 Need to remove it
# # install files
# unless File.exists?(Rails.root.to_s + '/public/javascripts/calendar_date_select/calendar_date_select.js')
#   ['/public', '/public/javascripts/calendar_date_select', '/public/stylesheets/calendar_date_select', '/public/images/calendar_date_select', '/public/javascripts/calendar_date_select/locale'].each do |dir|
#     source = File.join(directory,dir)
#     dest = Rails.root + dir
#     FileUtils.mkdir_p(dest)
#     FileUtils.cp(Dir.glob(source+'/*.*'), dest)
#   end
# end

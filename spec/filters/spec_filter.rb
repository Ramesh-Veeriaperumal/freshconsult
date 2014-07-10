class SpecFilter < SimpleCov::Filter

  FRESHFONE_FILTERS = [
    'app/controllers/freshfone/autocomplete_controller.rb',
    'app/models/freshfone_notifier.rb',
    'app/helpers/freshfone/call_history_helper.rb',
    'app/helpers/admin/freshfone/numbers_helper.rb',
    'app/helpers/admin/freshfone_helper.rb',
    'lib/freshfone/ops_notifier.rb',
    'lib/freshfone/callback_urls.rb'
  ]

  SPEC_FILTERS = [ FRESHFONE_FILTERS ].flatten

  def matches?(src)
    SPEC_FILTERS.find {|file| src.filename =~ /#{file}/} 
  end

end
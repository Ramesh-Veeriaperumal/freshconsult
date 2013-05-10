class CalendarDateSelect
  module IncludesHelper
    def calendar_date_select_includes(*args)
      return "" if @cds_already_included
      @cds_already_included=true
      
      options = (Hash === args.last) ? args.pop : {}
      options.assert_valid_keys(:style, :format, :locale)
      
      style = options[:style] || args.shift
      locale = options[:locale]
      cds_css_file = style ? "calendar_date_select/#{style}" : "calendar_date_select/default"
      
      output = []
      output << %( <script src="/javascripts/calendar_date_select/calendar_date_select.js" type="text/javascript"></script> )
      output << %( <script src="/javascripts/calendar_date_select/locale/#{locale}.js" type="text/javascript"></script> ) if locale
      output << %( <script src="/javascripts/#{CalendarDateSelect.javascript_format_include}.js" type="text/javascript"></script> ) if CalendarDateSelect.javascript_format_include
      output << %( <link href="/stylesheets/#{cds_css_file}.css" media="screen" rel="stylesheet" type="text/css"> )
      output * "\n"
    end
  end
end

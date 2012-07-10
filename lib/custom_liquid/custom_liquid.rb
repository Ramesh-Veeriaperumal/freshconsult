module CustomLiquid
  #@@liquid_filters = [CoreFilters, DropFilters, UrlFilters]
  @@liquid_tags    = "ABCD"
  #{:translate => Liquid::Tags::Translate}
  mattr_reader :liquid_tags
  #, :liquid_filters
end                                           
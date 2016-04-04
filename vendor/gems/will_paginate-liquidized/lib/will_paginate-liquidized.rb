# register the WillPaginate Liquid filter - fall through if class doesn't exist
# TODO-RAILS3 Need to test link_rederer is upgraded
require "will_paginate/view_helpers"
require "will_paginate/view_helpers/link_renderer"
require "will_paginate/liquidized"
require "will_paginate/liquidized/view_helpers"
Liquid::Template.register_filter(WillPaginate::Liquidized::ViewHelpers) rescue nil
module Helpdesk::DashboardHelper
  def pageless(total_pages, url=nil, container=nil)
    opts = {
      :totalPages => total_pages,
      :url        => url,
      :loaderMsg  => 'Loading more activities'
    }
    
    container && opts[:container] ||= container
    
    javascript_tag("jQuery('#Pages').pageless(#{opts.to_json});")
  end
end

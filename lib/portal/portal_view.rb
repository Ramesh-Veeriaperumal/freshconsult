# PortalView is a action view extension class to LiquidView
# and use liquid as an template system for .portal files
# @venom
class PortalView 

  PROTECTED_ASSIGNS = %w( template_root response _session template_class action_name request_origin session template
                          _response url _request _cookies variables_added _flash params _headers request cookies
                          ignore_missing_templates flash _params logger before_filter_chain_aborted headers )
  PROTECTED_INSTANCE_VARIABLES = %w( @_request @controller @_first_render @_memoized__pick_template @view_paths 
                                     @helpers @assigns_added @template @_render_stack @template_format @assigns )

  #List of variables that will be ignored before pushing to liquid
  PROTECTED_APP_VARIABLES = %w{ dynamic_template }
  
  def self.call(template)
    "PortalView.new(self).render(template, local_assigns)"
  end

  def initialize(view)
    @view = view
  end
  
  def render(template, local_assigns = nil, buffer=nil, &block)    
    return template.source if @view.controller.headers["Content-Type"] == 'text/plain'

    @view.controller.headers["Content-Type"] ||= 'text/html; charset=utf-8'    

    # The template key that should be used when retriving dynamic page or template information
    template_key = 'dynamic_template'

    # Using dynamic_template if it is present else fetch from the render file
    # local_assigns[template_key.to_sym] ||= @view.instance_variable_get("@#{template_key}")
    
    # Getting the source for the current view 
    # will be either the actual file or local assigns/instance variable with the name 'dynamic_template'
    source = (local_assigns[template_key.to_sym].blank?) ?
                (template.respond_to?(:source) ? template.source : template) :
                (local_assigns[template_key.to_sym])

    # Rails 2.2 Template has source, but not locals
    if template.respond_to?(:source) && !template.respond_to?(:locals)
      assigns = (@view.instance_variables - PROTECTED_INSTANCE_VARIABLES).inject({}) do |hash, ivar|
                  hash[ivar[1..-1]] = @view.instance_variable_get(ivar)
                  hash
                end
    else
      assigns = @view.assigns.reject{ |k,v| PROTECTED_ASSIGNS.include?(k) }
    end    
    
    local_assigns = (template.respond_to?(:locals) ? template.locals : local_assigns) || {}
    
    # Mergin all local assigns to be passed into the liquid ref.
    # Removing dynamic template information, 
    # to avoid re-rendering of base information in view if it is used within the template
    assigns.merge!(local_assigns.stringify_keys) - PROTECTED_APP_VARIABLES

    controller = @view.controller
    filters = if controller.respond_to?(:liquid_filters, true)
                controller.send(:liquid_filters)
              elsif controller.respond_to?(:master_helper_module)
                [controller.master_helper_module]
              else
                [controller._helpers]
              end

    if content_for_layout = @view.instance_variable_get("@content_for_layout")
      assigns['content_for_layout'] = @view.instance_variable_get("@page").content || content_for_layout
      assigns['content_for_layout'] = Liquid::Template.parse(assigns['content_for_layout']).render(assigns, :filters => filters, :registers => {:action_view => @view, :controller => @view.controller})
    end

    liquid = Liquid::Template.parse(source)
    liquid.render(assigns, :filters => filters, :registers => {:action_view => @view, :controller => @view.controller})
  end

  def compilable?
    false
  end

end
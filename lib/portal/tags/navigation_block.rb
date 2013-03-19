class Portal::Tags::NavigationBlock < Liquid::Block

  include LiquidExtensions::Helpers
  attr_accessor :links
      
  def initialize(name, params, tokens)
    @links = []
    super
  end

  def unknown_tag(name, params, tokens)
    if name == "link"
      handle_link_tag(params)
    else
      super
    end
  end

  def handle_link_tag(params)
    args = split_params(params)
    element_id = args[0].downcase
    if args.length > 1
      match = (args[1].first == "/" ? args[1][1..-1] : element_id)
      @links << { :name => args[0], :match => match, :url => args[1], :id => element_id, :extra_class => args[2] }
    else
      @links << { :name => args[0], :match => element_id, :url => "/#{element_id}", :id => element_id }
    end
  end

  def split_params(params)
    params.split(",").map(&:strip)
  end

  def render(context)
    output = <<HTML "<ul id="navigation">
      @links.each do |link|
        <li class="<%= link[:id] %><%= match_class registers, link %><%= extra_class link %>">
          <%= link_to link[:name], link[:url] %>
        </li>
      end
    </ul>
HTML
  end

end
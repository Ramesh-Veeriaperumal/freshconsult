class Portal::Tags::Snippet < Liquid::Tag

  def initialize(tag_name, markup, tokens)
    super
    @name = markup
    @name.strip!
  end

  def render(context)
    render_erb(context, @name, :registers => context.registers)
  end

  def render_erb(context, file_name, locals = {})
    context.registers[:controller].send(:render_to_string, :partial => file_name, :locals => locals)
  end

end
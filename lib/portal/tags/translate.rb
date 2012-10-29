class Portal::Tags::Translate < Liquid::Tag

  def initialize(tag_name, markup, tokens)
    super
    @translate_key = markup.split[0]
    @attributes = {}
    markup.scan(Liquid::TagAttributes) do |key, value|
      @attributes[key.to_sym] = value
    end
  end

  def render(context)
    # !PORTALCSS adding a hard portal hash parent key
    # need to rethink this so the it can be flexible enough to add any key translation
    context.registers[:controller].send(:t, "portal.#{@translate_key}", @attributes)
  end

end
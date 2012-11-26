class Portal::Tags::Translate < Liquid::Tag

  def initialize(tag_name, markup, tokens)
    super
    @translate_key = markup.split[0].downcase
    @attributes = {}
    markup.scan(Liquid::TagAttributes) do |key, value|
      @attributes[key.to_sym] = value
    end
  end

  def render(context)
    # Direct translation key being set for portal translation.
    # User will be able to use keys directly from our local key file
    context.registers[:controller].send(:t, "#{@translate_key}", @attributes)
  end

end
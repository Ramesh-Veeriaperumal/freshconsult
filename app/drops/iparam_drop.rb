class IparamDrop < BaseDrop

  def initialize(source)
    super source
  end

  def before_method(method)
    @source[method]
  end
end

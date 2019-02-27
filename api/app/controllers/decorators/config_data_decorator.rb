class ConfigDataDecorator < ApiDecorator
  def freshvisuals
    {
      url: record[:config]
    }
  end
end

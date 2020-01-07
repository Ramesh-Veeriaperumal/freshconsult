class ConfigDataDecorator < ApiDecorator
  def freshvisuals
    {
      url: record[:config]
    }
  end

  def freshsales
    {
      url: record[:config]
    }
  end
end

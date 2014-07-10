class Integrations::Mapper::HashHandler
  def fetch(data, config)
    fetch_using = config[:fetch_using]
    if fetch_using.blank?
      data
    else
      data[fetch_using]
    end
  end
end

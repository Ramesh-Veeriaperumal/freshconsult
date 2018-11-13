if @item.contact_info.present?
  @item.contact_info.each_pair do |key, value|
    json.set! key, value
  end
end
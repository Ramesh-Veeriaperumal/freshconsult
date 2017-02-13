class FacebookPageDecorator < ApiDecorator
  delegate :id, :profile_id, :page_id, :page_name, :page_img_url, :page_link, :enable_page, :product_id, to: :record

  def to_hash
    {
      id: id,
      profile_id: profile_id,
      page_id: page_id,
      page_name: page_name,
      page_image_url: page_img_url,
      page_link: page_link,
      enable_page: enable_page,
      product_id:product_id
    }
  end
end

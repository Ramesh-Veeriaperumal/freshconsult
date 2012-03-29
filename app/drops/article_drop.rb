class ArticleDrop < BaseDrop
  
  timezone_dates :published_at, :updated_at
  liquid_attributes << :title << :permalink << :comments_count
  
  def initialize(source, options = {})
    super source
    @options = options
    @liquid.update \
      'body'            => @source.description,
      'body_plain'      => @source.desc_un_html,
      'is_page_home'    => (options[:page] == true)
  end
end  
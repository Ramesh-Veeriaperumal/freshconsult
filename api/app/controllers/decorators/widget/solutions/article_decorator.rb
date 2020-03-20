class Widget::Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :language_id,
           :parent, :parent_id, :attachments, :modified_at, :modified_by, :id, to: :record

  def initialize(record, options)
    @widget_product_id = options[:widget_product_id] if options.present?
    super(record)
  end

  def to_search_hash
    {
      id: parent_id,
      title: title,
      modified_at: modified_at.try(:utc),
      language_id: language_id
    }
  end

  def to_hash
    to_search_hash.merge(
      attachments: attachments_hash,
      description: description,
      meta: meta_hash
    )
  end

  private

    def portal
      @portal ||= begin
        if @widget_product_id
          Account.current.portals.where(product_id: @widget_product_id).first
        else
          Account.current.main_portal_from_cache
        end
      end
    end

    def article_url_options
      url_options = { host: portal.host, protocol: portal.url_protocol }
      url_options[:url_locale] = Language.current.code if Account.current.multilingual?
      url_options
    end

    def portal_link
      return nil unless portal.try(:has_solution_category?, parent.solution_category_meta.id)

      Rails.application.routes.url_helpers.support_solutions_article_url(record, article_url_options)
    end

    def attachments_hash
      attachments.map { |a| AttachmentDecorator.new(a).to_hash }
    end

    def meta_hash
      {
        portal_link: portal_link
      }
    end
end

class SwaggerController < MetalApiController
  def respond
    if Rails.env.production?
      head 404
    else
      params[:path] ||= 'index.html'
      path = params[:path]
      path << ".#{params[:format]}" unless path.ends_with?(params[:format].to_s)
      render inline: File.read("#{Rails.root}/swagger/#{path}")
    end
  end
end

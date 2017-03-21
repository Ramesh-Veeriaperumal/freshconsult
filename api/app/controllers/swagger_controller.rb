class SwaggerController < MetalApiController
  
  def respond
    unless Rails.env.production?
      params[:path] ||= 'index.html'
      path = params[:path]
      path << ".#{params[:format]}" unless path.ends_with?(params[:format].to_s)
      render :inline => File.read("#{Rails.root}/swagger/#{path}")
    else
      head 404
    end
  end
end
class SwaggerController < MetalApiController
  
  def respond
    if Rails.env == "development"
      params[:path] ||= 'index.html'
      path = params[:path]
      path << ".#{params[:format]}" unless path.ends_with?(params[:format].to_s)
      render :inline => File.read("#{Rails.root}/api/swagger/#{path}")
    else
      head 404
    end
  end
end
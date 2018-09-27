module ApplicationsTestHelper

  def central_publish_app_pattern(app)
    {
      id: app.id,
      name: app.name,
      display_name: app.display_name,
      description: app.description
    }
  end
  
end
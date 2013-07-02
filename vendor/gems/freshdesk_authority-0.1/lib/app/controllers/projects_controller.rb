class ProjectsController < ActionController::Base
  
  def new
    @project  = Project.new
  end
  
  def create
    @project = Project.build(params[:project])
    @project.save
  end
  
  def edit
    @project = Project.find(params[:id])
  end
  
  def update
    @project = Project.find(params[:id])
    @project = Project.update_attributes(params[:project])
    @project.save
  end
  
  def destroy
    @project = Project.find(params[:id])
    @project.destroy
  end
end
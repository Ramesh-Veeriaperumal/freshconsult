class Helpdesk::VisitorController < ApplicationController
  before_filter :set_selected_tab 
  
  def index 
    puts "Visitor Index called..."
  end

  private
    def set_selected_tab
      @selected_tab = :dashboard
    end
end

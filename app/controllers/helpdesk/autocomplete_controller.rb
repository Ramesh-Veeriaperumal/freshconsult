class Helpdesk::AutocompleteController < ApplicationController
	
	def requester
		requesters = { :results => results.map { |i| {
                      :details => i.name_details, 
                      :id => i.id, :value => i.name
                  }}} 
		requesters[:results].push({ 
                  :id => current_account.kbase_email, 
                  :value => ""
                }) if params[:q] =~ /(kb[ase]?.*)/

		respond_to do |format|
			format.json { render :json => requesters.to_json }
		end
	end

  def customer
    customers = {:results => results.map { |i| {:id => i.id, :value => i.name}}} 

    respond_to do |format|
      format.json { render :json => customers.to_json }
    end
  end

  protected

  	def results
      @results ||= begin 
        return [] if params[:q].blank? 
        scoper.find(:all, :conditions => send("#{current_action}_conditions"), :limit => 100 )
      end
  	end
  	
  	def scoper
  		send("#{current_action}_scope")
  	end

    def current_action
      @current_action ||= begin
        allowed_actions = ['requester','customer']
        allowed_actions.include?(params[:action]) ? params[:action] : allowed_actions.first  
      end
    end

  	def requester_scope
  		current_account.users
  	end

  	def customer_scope
  		current_account.customers
  	end

  	def requester_conditions
  		["name like ? or email like ? or phone like ?","%#{params[:q]}%","%#{params[:q]}%","%#{params[:q]}%"]
  	end

  	def customer_conditions
  		["name like ?", "%#{params[:q]}%"]
  	end

end
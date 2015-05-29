# encoding: utf-8
class Solution::ArticlesController < ApplicationController

  include Helpdesk::ReorderUtility
  include CloudFilesHelper
  helper AutocompleteHelper
  
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
  before_filter :portal_check, :only => :show
  
  before_filter :set_selected_tab

  before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :page_title 
  before_filter :load_article, :only => [:update, :destroy, :reset_ratings]
  before_filter :load_meta_objects, :only => [:create, :new]
  before_filter :load_article_meta, :only => :edit
  before_filter :load_dynamic_objects, :only => :edit
  
  include Solution::MetaControllerMethods
  
  def index
    redirect_to solution_category_folder_url(params[:category_id], params[:folder_id])
  end

  def show
    @enable_pattern = true
    @article = current_account.solution_articles.find_by_id!(params[:id], :include => :folder)
    respond_to do |format|
      format.html
      format.xml  { render :xml => @article }
      format.json { render :json => @article }
    end    
  end

  def new
    current_folder = Solution::Folder.first
    current_folder = Solution::Folder.find(params[:folder_id]) unless params[:folder_id].nil?
    @article = current_folder.articles_without_meta.new  
    @article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @article }
    end
  end

  def edit 
    @article = current_account.solution_articles.new 
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @article }
    end
  end

  def create
    @article = @article_meta.solution_articles.new(params[nscname]) 
    set_item_user 

    redirect_to_url = @article
    redirect_to_url = new_solution_category_folder_article_path(params[:category_id], params[:folder_id]) unless params[:save_and_create].nil?
    build_attachments
    set_solution_tags
    set_outdated
    respond_to do |format|
      if (@category_by_language || create_language_category) && (@folder_by_language || create_language_folder) && @article_meta.save
        format.html { redirect_to redirect_to_url }        
        format.xml  { render :xml => @article, :status => :created, :location => @article }
        format.json  { render :json => @article, :status => :created, :location => @article }
      else
        format.html do 
          flash[:notice] = @article.errors.full_messages.to_sentence 
          redirect_to :back
        end
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def save_and_create    
    logger debug "Inside save and create"    
  end

  def update
    build_attachments
    set_solution_tags
    set_outdated
    respond_to do |format|   
      if @article.update_attributes(params[nscname])  
        format.html { redirect_to @article }
        format.xml  { render :xml => @article, :status => :created, :location => @article }     
        format.json  { render :json => @article, :status => :ok, :location => @article }    
      else
        p @article.errors
        format.html { redirect_to :back }
        format.xml  { render :xml => @article.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @article.destroy
    
    respond_to do |format|
      format.html { redirect_to(solution_category_folder_url(params[:category_id],params[:folder_id])) }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end
   

   def delete_tag  #possible dead code
     logger.debug "delete_tag :: params are :: #{params.inspect} "     
     article = current_account.solution_articles.find(params[:article_id])     
     tag = article.tags.find_by_id(params[:tag_id])      
     raise ActiveRecord::RecordNotFound unless tag
     Helpdesk::TagUse.find_by_article_id_and_tag_id(article.id, tag.id).destroy
    flash[:notice] = t(:'flash.solutions.remove_tag.success')
    redirect_to :back    
   end

  def reset_ratings
    @article.update_attributes(:thumbs_up => 0, :thumbs_down => 0 )
    @article.votes.destroy_all
  
    respond_to do |format|
      format.js
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  protected

    def load_article
      @article = current_account.solution_articles.find(params[:id])
    end

    def load_article_meta
      @article_meta = current_account.solution_article_meta.find(params[:id])
      @folder_meta = @article_meta.solution_folder_meta
      @category_meta = @folder_meta.solution_category_meta
    end

    def load_dynamic_objects
      @supported_languages = current_account.account_additional_settings.supported_languages
      @default_language = current_account.language
      @all_languages = [@default_language] + @supported_languages
      dynamic_articles = current_account.solution_articles.find(:all, :conditions => { :parent_id => params[:id], :language => @all_languages })
      @dynamic_articles_by_language = Hash[*dynamic_articles.map { |a| [a.language, a] }.flatten]
      dynamic_folders = current_account.folders.find(:all, :conditions => { :parent_id => @folder_meta.id, :language =>  @all_languages })
      @dynamic_folders_by_language = Hash[*dynamic_folders.map { |f| [f.language, f] }.flatten]
      dynamic_categories = current_account.solution_categories.find(:all, :conditions => { :parent_id => @category_meta.id, :language =>  @all_languages })
      @dynamic_categories_by_language = Hash[*dynamic_categories.map { |c| [c.language, c] }.flatten]
    end

    def scoper #possible dead code
      eval "Solution::#{cname.classify}"
    end

    def build_attachments
      attachment_builder(@article, params[nscname][:attachments], params[:cloud_file_attachments] )
    end
    
    def reorder_scoper
      current_account.solution_articles.find(:all, :conditions => {:folder_id => params[:folder_id] })
    end
    
    def reorder_redirect_url
      solution_category_folder_url(params[:category_id], params[:folder_id])
    end

    def cname #possible dead code
      @cname ||= controller_name.singularize
    end

    def nscname
      @nscname ||= controller_path.gsub('/', '_').singularize
    end
    

    def set_item_user
      @article.user ||= current_user if (@article.respond_to?('user=') && !@article.user_id)
      @article.account ||= current_account
    end

    def set_selected_tab
      @selected_tab = :solutions
    end     
    
    def page_title
      @page_title = t("header.tabs.solutions")    
    end

		def meta_parent
			"solution_article_meta"
		end

    def load_meta_objects
      @category_meta = current_account.solution_category_meta.find_by_id(params[:category_id])
      @folder_meta = @category_meta.solution_folder_meta.find_by_id(params[:folder_id])
      @article_meta = @folder_meta.solution_article_meta.find_by_id(params[:article_meta_id])
      @category_by_language = @category_meta.solution_categories.find_by_language(params[:language] || current_account.language)
      @folder_by_language = @folder_meta.solution_folders.find_by_language(params[:language] || current_account.language)
    end

    def create_language_category
      category_by_language =  @category_meta.solution_categories.new(params[:category])
      category_by_language.language = params[:language]
      category_by_language.save || push_errors_to_base(category_by_language)
    end

    def create_language_folder
      folder_by_language =  @folder_meta.solution_folders.new(params[:folder])
      folder_by_language.language = params[:language]
      folder_by_language.save || push_errors_to_base(folder_by_language)
    end

    def push_errors_to_base(obj)
      @article.errors.add(obj.class.name.to_sym, obj.errors.messages)
      false
    end

    def set_solution_tags      
      return unless params[:tags] && (params[:tags].is_a?(Hash) && params[:tags][:name].present?)      
      @article.tags.clear    
      tags = params[:tags][:name]
      ar_tags = tags.split(',').map(&:strip).uniq    
      new_tag = nil

      ar_tags.each do |tag|      
        new_tag = Helpdesk::Tag.find_by_name_and_account_id(tag, current_account) ||
           Helpdesk::Tag.new(:name => tag ,:account_id => current_account.id)
        begin
          @article.tags << new_tag
        rescue ActiveRecord::RecordInvalid => e
        end

      end   
    end

    def set_outdated
      if @article.default?
        return if params[nscname][:outdated].to_bool
        current_account.solution_articles.update_all(
                                            {:outdated => true}, 
                                            ["solution_articles.parent_id = ? AND solution_articles.language in (?)", 
                                              params[:id],current_account.account_additional_settings.supported_languages]
                                            )
      else
        @article.outdated = params[nscname][:outdated]
      end
      params[nscname].delete(:outdated)
    end
    
    def portal_check
      format = params[:format]
      if format.nil? && (current_user.nil? || current_user.customer?)
        return redirect_to support_solutions_article_path(params[:id])
      elsif !privilege?(:view_solutions)
        access_denied
      end
    end
end

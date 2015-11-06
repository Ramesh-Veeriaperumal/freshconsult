module SolutionBuilderHelper

  def solution_default_params(base, name = :name)
    {
      "#{name}" => "#{base} #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name} - #{Time.now.to_s}",
      "description" => "#{Faker::Lorem.sentence(rand(1..10))}"
    }.deep_symbolize_keys
  end

  def create_solution_category_alone(params = {})
    {
      :solution_category_meta => {
        :id => params[:id] || nil,
      }.merge(solution_lang_ver_hash(:category, params[:lang_codes], params.except(:lang_codes, :id)))
    }.deep_symbolize_keys
  end

  def create_solution_folder_alone(params = {})
    {
      :solution_folder_meta => {
        :id => params[:id] || nil,
        :visibility => params[:visibility] || 1,
        :solution_category_meta_id => params[:category_id] || nil,
      }.merge(solution_lang_ver_hash(:folder, params[:lang_codes], params.except(:lang_codes, :id, :category_id, :visibility)))
    }.deep_symbolize_keys
  end

  def create_solution_article_alone(params = {})
    params[:user_id] = @agent.id if params[:user_id].blank?
    {
      :solution_article_meta => {
        :id => params[:id] || nil,
        :art_type => params[:art_type] || 1,
        :solution_folder_meta_id => params[:folder_id] || nil
      }.merge(solution_lang_ver_hash(:article, params[:lang_codes], params.except(:lang_codes, :folder_id, :art_type, :id)))
    }.deep_symbolize_keys
  end

  def solution_lang_ver_hash(base, lang_codes, params = {})
    final = {}
    lang_codes = [:primary] unless lang_codes.present?
    lang_codes.each do |lang_code|
      key = params.keys.include?(:name) ? :name : :title
      final["#{lang_code}_#{base}"] = params.dup
      final["#{lang_code}_#{base}"][key] = "#{lang_code} #{params[key]}" if key.present?
    end
    final.deep_symbolize_keys
  end

  def solution_api_article(params = {})
    {
      "solution_article" => {
        "title" => params[:title] || "Article on #{(Time.now.to_f * 1000).to_i} #{Faker::Name.name}",
        "status" => params[:status] || 1,
        "art_type" => params[:art_type] || 2,
        "description" => params[:description] || "#{Faker::Lorem.sentence(3)}",
        "folder_id" => params[:folder_id] || nil,
        "user_id" => @agent.id
      },
      "tags" => params[:tags] || { "name" => "tag1, tag2"}
    }.deep_symbolize_keys
  end

  def solution_api_folder(params = {})
    {
       "solution_folder" => {
          "name" => params[:name] || "Folder on #{(Time.now.to_f * 1000).to_i} #{Faker::Name.name}",
          "visibility" => params[:visibility] || 1,
          "description" => params[:description] || "#{Faker::Lorem.sentence(2)}"
       }
    }.deep_symbolize_keys
  end

  def solution_api_category(params = {})
    {
      "solution_category" => {
        "name" => params[:name] || "Category on #{(Time.now.to_f * 1000).to_i} #{Faker::Name.name}",
        "description" => params[:description] || "#{Faker::Lorem.sentence(1)}"
      }
    }.deep_symbolize_keys
  end

end
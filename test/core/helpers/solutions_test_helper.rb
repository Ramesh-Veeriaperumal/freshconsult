module CoreSolutionsTestHelper

  def solution_default_params(base, name = :name, opts = {})
    {
      "#{name}" => opts[name] || "#{base} #{(Time.now.to_f * 1000).to_i} on #{Faker::Name.name}",
      "description" => opts[:description] || "#{Faker::Lorem.sentence(rand(1..10))}"
    }.deep_symbolize_keys
  end

  def create_solution_category_alone(params = {})
    {
      :solution_category_meta => {
        :id => params[:id] || nil      
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
      final["#{lang_code}_#{base}"][:status] ||= 2 if base == :article
    end
    final.deep_symbolize_keys
  end

  def create_category(params = {})
    c_params = create_solution_category_alone(solution_default_params(:category, :name, {
      :name => params[:name] || Faker::Name.name,
      :description => params[:description] || Faker::Lorem.paragraph
    }))
    c_params[:solution_category_meta][:is_default] = params[:is_default] if params[:is_default].present?
    c_params[:solution_category_meta][:portal_ids] = params[:portal_ids] if params[:portal_ids].present?
    category_meta = Solution::Builder.category(c_params)
    category_meta
  end

  def create_folder(params = {})
    f_params = create_solution_folder_alone(solution_default_params(:folder, :name, {
        :name => params[:name] || Faker::Name.name,
        :description => params[:description] || Faker::Lorem.paragraph
      }).merge({
        :category_id => params[:category_meta_id] || params[:category_id] || create_category.id,
        :visibility => params[:visibility] || Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:anyone]
      }))
    f_params[:solution_folder_meta][:is_default] = params[:is_default] if params[:is_default].present?
    folder_meta = Solution::Builder.folder(f_params)
    folder_meta
  end

  def create_article(params = {})
    params = create_solution_article_alone(solution_default_params(:article, :title, {
      :title => params[:title] || Faker::Lorem.words(5).join(' '),
      :description => params[:description] || Faker::Lorem.paragraph
      }).merge({
        :folder_id => params[:folder_meta_id] || params[:folder_id] || create_folder.id,
        :art_type => params[:art_type] || Solution::FolderMeta::TYPE_KEYS_BY_TOKEN[:permanent],
        :status => params[:status] || 2,
        :user_id => params[:user_id] || @agent.id,
        attachments: params[:attachments],
        suggested: params[:suggested] || 0
      }))
    current_user_present = User.current.present?
    Account.current.users.find(params[:user_id] || @agent.id).make_current unless current_user_present
    article_meta = Solution::Builder.article(params.deep_symbolize_keys)
    User.reset_current_user unless current_user_present
    article_meta
  end
end
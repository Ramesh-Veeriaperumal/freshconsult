class ActiveRecord::Associations::BelongsToPolymorphicAssociation 
  
  def conditions
   @conditions ||= interpolate_sql(association_class.send(:sanitize_sql, @reflection.options[:conditions])) if @reflection.options[:conditions]
  end
 
end
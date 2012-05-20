(function( $ ){

  var methods = {
     init : function( tree, options ) {

       return this.each(function(){
         var opts = $.extend( {}, $.fn.nestedselect.defaults, options ),
             _fields = opts.nested_fields,
             _init = opts.initData,
             category = $("<select name='value' />"),
             category_name = $("<input type='hidden' value='"+opts.category_name+"' name='name' />"),
             subcategory = $("<select />"),
             items = $("<select />"),
             rule_type = $("<input type='hidden' name='rule_type' value='nested_rule' />"),
             nested_rules = $("<input type='hidden' name='nested_rules' value='' />");
        
        
           (tree.getCategoryList()||[]).each(function(key){
              $("<option />")
                .html(key)
                .val(key)
                .appendTo(category);
            });

         category
            .val(_init.value || "")
            .bind("change", function(ev){
              subcategory.empty();
              (tree.getSubcategoryList(category.val())||[]).each(function(pair){
                $("<option />")
                  .html(pair.key)
                  .val(pair.key)
                  .appendTo(subcategory);
            });

            subcategory.trigger("change");
         });

         subcategory.bind("change", function(ev){
          if(!subcategory.data("initialLoad")){         
            if(_init.nested_rules) subcategory.val(_init.nested_rules[0].value);
            subcategory.data("initialLoad", true);
          }
          if(tree.third_level){
            item.empty();
            (tree.getItemsList(category.val(), subcategory.val())).each(function(pair){
              $("<option />")
                .html(pair.key)
                .val(pair.key)
                .appendTo(item);
            });  
            items.trigger("change");
          }else{
            methods.setNestedRule(nested_rules, _fields.subcategory.name, subcategory.val(), _fields.items.name, items.val());
          }
         })

         items.bind("change", function(ev){
            methods.setNestedRule(nested_rules, _fields.subcategory.name, subcategory.val(), _fields.items.name, items.val());
         });

         category.trigger("change");
         if(opts.type != "action"){
            $(this).append(category)
                   .append(category_name)
                   .append(subcategory);

            if(tree.third_level)
              $(this).append(items);

            $(this).append(rule_type)
                   .append(nested_rules);

            
         }else{
            category_name.prop("value", "set_nested_fields");
            $(this).append(category_name)
                   .append("<input type='hidden' name='category_name' value='"+opts.category_name+"' />")
                   .append(category)
                   .append(nested_rules)
                   .append(subcategory);

            if(tree.third_level)
              $(this).append(items);
         }
       });

     }, 
     setNestedRule : function( nested_rules, subcategory_name, subcategory, item_name, item ){
        //console.log(item);
        item_check = (item) ? (', { name : '+item_name+', value : '+item+' }') : "";
        nested_rules.val('[{ name :'+subcategory_name+', value : '+subcategory+'}'+item_check+']');
     }
  };

  $.fn.nestedselect = function( method ) {
    
    if ( methods[method] ) {
      return methods[method].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.nestedselect' );
    }    
  
  };

  // publicly accessible defaults
  $.fn.nestedselect.defaults = {
     category_name:  "",
     nested_fields: { subcategory : { name : "", label : "" }, items : { name : "", label : "" } },
     initData: ({value:"", nested_rules:[{value:""}, {value:""}]})
  };


})( jQuery );
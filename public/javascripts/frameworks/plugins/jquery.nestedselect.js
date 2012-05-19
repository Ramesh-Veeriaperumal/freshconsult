(function( $ ){

  var methods = {
     init : function( tree, options ) {

       return this.each(function(){
         var opts = $.extend( {}, $.fn.nestedselect.defaults, options ),
             _fields = opts.nested_fields,
             _init = opts.initData,
             category = $("<select name='value' />").append(tree.getCategory()).val(_init.value || ""),
             category_name = $("<input type='hidden' value='"+opts.category_name+"' name='name' />"),
             category_val = category.children('option:selected').text(),
             subcategory = $("<select />").append(tree.getSubcategory(category_val)),
             subcategory_val = subcategory.children('option:selected').text(),
             items = $("<select />").append(tree.getItems(category_val, subcategory_val)),
             rule_type = $("<input type='hidden' name='rule_type' value='nested_rule' />"),
             nested_rules = $("<input type='hidden' name='nested_rules' value='' />");

         category.bind("change", function(ev){
            subcategory
                .html(tree.getSubcategory($(this).children('option:selected').text()))
                .trigger("change");
         });

         subcategory.bind("change", function(ev){
            items.html(tree.getItems(category.children('option:selected').text(), $(this)
                 .children('option:selected').text()))
                 .trigger("change");
         })

         items.bind("change", function(ev){
            methods.setNestedRule(nested_rules, _fields.subcategory.name, subcategory.val(), _fields.items.name, items.val());
         });

         if(_init.nested_rules){
            subcategory.val(_init.nested_rules[0].value || "").trigger("change");
            items.val(_init.nested_rules[1].value || "").trigger("change");
         }

         if(opts.type != "action"){
            $(this).append(category)
                   .append(category_name)
                   .append(subcategory);

            if(_fields.items != "")
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

            if(_fields.items != "")       
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
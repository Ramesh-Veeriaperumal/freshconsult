(function( $ ){

  var methods = {
     init : function( tree, options, value, _dataAttr ) {

       return this.each(function(){
        nested_rules_name = ""
        switch (value){
          case undefined:
          case 'value':
            nested_rules_name = 'nested_rules'
            break;
          default :
            nested_rules_name = value+"_nested_rules"
        } 
         var opts = $.extend( {}, $.fn.nestedselect.defaults, options ),
             _fields = opts.nested_fields,
             _init = opts.initData,
             category = $("<select name='"+value+"' />"),
             category_name = $("<input type='hidden' value='"+opts.category_name+"' name='name' />"),
             subcategory = $("<select />"),
             items = $("<select />"),
             special_cases = { '--':'Any Value', '':'None', '0':'None' },

             rule_type = $("<input type='hidden' name='rule_type' value='nested_rule' />"),
             nested_rules = $("<input type='hidden' name='"+nested_rules_name+"' value='' />");

             if (_dataAttr){ 
              category.data( _dataAttr);
              subcategory.data( _dataAttr);
              items.data( _dataAttr);
             }
          
           (tree.getCategoryList()||[]).each(function(key){
              value = $.inArray(key, Object.keys(special_cases))!=-1 ? special_cases[key] : key
              $("<option />")
                .html(value)
                .val(key)
                .appendTo(category);
            });

         category
            .val(_init.value)
            .bind("change", function(ev){
              subcategory.empty();

              (tree.getSubcategoryListWithNone(category.val())).each(function(pair){
                value = $.inArray(pair.value.id, Object.keys(special_cases))!=-1 ? special_cases[pair.value.id] : pair.value.id
                $("<option />")
                  .html(value)
                  .val(pair.key)
                  .appendTo(subcategory);
            });

            subcategory.trigger("change");
         });

         subcategory.bind("change", function(ev){
          if(!subcategory.data("initialLoad")){         
            if(_init.nested_rules && _init.nested_rules[0]) subcategory.val(_init.nested_rules[0].value);
            subcategory.data("initialLoad", true);
          }
          if(tree.third_level){
            items.empty();
            (tree.getItemsListWithNone(category.val(), subcategory.val())).each(function(pair){
              value = $.inArray(pair.value.id, Object.keys(special_cases))!=-1 ? special_cases[pair.value.id] : pair.value.id

              $("<option />")
                .html(value)
                .val(pair.key)
                .appendTo(items);
            });  
            items.trigger("change");
          }else{
            methods.setNestedRule(nested_rules, _fields.subcategory.name, subcategory.val(), _fields.items.name, items.val());
          }
          methods.hideEmptySelectBoxes(this)
         })

         items.bind("change", function(ev){
            if(!items.data("initialLoad")){
              if(_init.nested_rules && _init.nested_rules[1]) items.val(_init.nested_rules[1].value);
              items.data("initialLoad", true);
            }

            methods.setNestedRule(nested_rules, _fields.subcategory.name, subcategory.val(), _fields.items.name, items.val());
            methods.hideEmptySelectBoxes(this)
         });

         if(opts.type == "event"){
           $(this).append(category)
                   .append(category_name)
                   .append($("<div/>").append(subcategory));

            if(tree.third_level){ 
              $(this).append($("<div/>").append(items));
            }
            $(this).append(rule_type)
                   .append(nested_rules); 
         }else if(opts.type != "action"){
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

         var selectopts = { minimumResultsForSearch : 10 }
         if(_init.value=='')
          {$(category).attr('placeholder', 'None');} // Hack coz select2 takes the first value as placeholder,
                                                                                  // when its value is set to null

         category.select2(selectopts)
         subcategory.select2(selectopts)
         items.select2(selectopts)

         category.trigger("change"); 
       });

     }, 

     hideEmptySelectBoxes : function(select_box){
        options = $.map(select_box.options, function(opt){ return opt.value})
        // Below used ''+[] for converting arrays to strings n comapring
        if(select_box.options.length == 0 || ''+options == ''+["--"] || ''+options == ''+[""]){
          $(select_box).prev().css('display','none');
        }else{
          $(select_box).prev().css('display','block');
        }
    },

     setNestedRule : function( nested_rules, subcategory_name, subcategory, item_name, item ){
        item_val = ', { "name" : "'+item_name+'", "value" : "'+(item||'')+'" }' ;
        nested_rules.val('[{ "name" : "'+subcategory_name+'", "value" : "'+(subcategory||'')+'" }'+item_val+']');
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
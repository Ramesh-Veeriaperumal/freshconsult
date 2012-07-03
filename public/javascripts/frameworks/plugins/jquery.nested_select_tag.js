(function( $ ){

  var methods = {
     init : function( options ) {
       return this.each(function(){
         var defaults = $.fn.nested_select_tag.defaults;
            
         var opts = $.extend( {}, defaults, options ),
            _tree = new NestedField(opts.data_tree),
            _category = $(this),
            _subcategory = $("#" + opts.subcategory_id),
            _item = $("#" + opts.item_id),
            _vals = (opts.initValues || {});

         opts["default_option"] = "<option value=''>"+opts["include_blank"]+"</option>";   

         _category.bind("change", function(ev){
            var _items_present = false;
            _subcategory.html(opts.default_option);
            (_tree.getSubcategoryList(_category.val())).each(function(pair){
              _items_present = true;
              $("<option />")
                .html(pair.key)
                .val(pair.key)
                .appendTo(_subcategory);
            });
            
            _subcategory.trigger("change");
            _condition = (!_items_present || (!_category.val() || _category.val() == -1));

            _subcategory.prop("disabled", _condition).parent().toggle(!_condition);
         });

         _subcategory.bind("change", function(ev){
            if(!_subcategory.data("initialLoad")){              
              _subcategory.val(_vals["subcategory_val"]);
              _subcategory.data("initialLoad", true);
            }else{
              if(!_item.get(0))
                opts.change_callback();
            }
            if(_tree.third_level){
              var _items_present = false;
              _item.html(opts.default_option);
              (_tree.getItemsList(_category.val(), _subcategory.val())).each(function(pair){
                _items_present = true;
                $("<option />")
                  .html(pair.key)
                  .val(pair.key)
                  .appendTo(_item);
              });                 
              _item.trigger("change");
              _condition = (!_items_present || (!_subcategory.val() || _subcategory.val() == -1));
              _item.prop("disabled", _condition).parent().toggle(!_condition);
            }
         });

         _item.bind("change", function(ev){
            if(_item.data("initialLoad")){
               opts.change_callback();             
            }else{              
              _item.val(_vals["item_val"]);
              _item.data("initialLoad", true);
            }
         });

         _category
          .val(_vals["category_val"])
          .trigger("change");
          

       });
     }
  };

  $.fn.nested_select_tag = function( method ) {
    
    if ( methods[method] ) {
      return methods[method].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.nested_select_tag' );
    }    
  
  };

  // publicly accessible defaults
  $.fn.nested_select_tag.defaults = {
     data_tree: [],
     initValues: {},
     include_blank: "...",
     default_option: "<option value=''>...</option>",
     inline_labels: true,
     change_callback: function(){}
  };


})( jQuery );
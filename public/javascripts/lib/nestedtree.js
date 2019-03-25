/**
 * @author venom
 * Tree hash that is used in the Ticket form customizer
 * The object can parse two type of data 
 * First a string intended with tabs 
 *  _category = no tabs
 *      _subcategory = one tab
 *          _item = two tabs
 * Second an two dimensional array in the following format
 * [[ category, 0, 
 *      [subcategory, 0, 
 *          [item, 0]]]]        
 
 * The data set can return the obj in the folloing ways
 * 1. The same array format
 * 2. The same string format
 * 3. A set of select options for each category, subcategory or item
 */ 

var $t = Class.create({
  initialize: function(id, listId) {
    this.id = id || "0";
    this.listId = listId || 0;
    this.children = $H();
  },
  set: function(key, child){
    this.children.set(key, child);
  },
  get: function(key){
    return (key != "...") ? this.children.get(key) : "";
  }
});

var NestedField = Class.create({
  initialize: function(data, feature_check) {                  
    this._blank = "...";   
    this.tree = new $H();
    this.revamped = feature_check;
    this.readData(data);
  },
  readData: function(data){
    delete this.tree;
    this.tree = new $H();
    this.third_level = this.second_level = false;
   	if(typeof data == "string")
    	this.parseString(data);      
    else if(typeof data == "object")
      this.revamped ? this.parseObjectArray(data) : this.parseObject(data);
  },
  removeTests: function(text){
    return text.replace(/[\t\r]/g, '').strip();
  },
  testChar: function(text){
    return /[\t\r]/g.test(text);
  },
  parseObject: function(_obj){
  _self = this; 
    _obj.each(function(_category){
      _self.tree.set(_category[0], new $t(_category[1]));     
      if(!_category[2]) return;
          _category[2].each(function(_subcategory){
           _self.tree.get(_category[0]).set(_subcategory[0], new $t(_subcategory[1]));
           _self.setSecondPresent();
           if(!_subcategory[2]) return;
            _subcategory[2].each(function(_item){
                _self.tree.get(_category[0]).get(_subcategory[0]).set(_item[0], new $t(_item[1]));
                _self.setThirdPresent();
            });
        });
    });
  },        
  parseObjectArray: function(_obj){
	_self = this;
  var count = 0;
  	_obj.each(function(_category){
      if(!_category.id) {
        _category.id = Date.now() + count;
        count++;
      }
  		_self.tree.set(_category.value, new $t(_category.value, _category.id));    
  		if(!_category.choices) return;
  		    _category.choices.each(function(_subcategory){
            if(!_subcategory.id) {
              _subcategory.id = Date.now() + count;
              count++;
            }
  				 _self.tree.get(_category.value).set(_subcategory.value, new $t(_subcategory.value, _subcategory.id));
           _self.setSecondPresent();
  				 if(!_subcategory.choices) return;
  					_subcategory.choices.each(function(_item){
                if(!_item.id) {
                  _item.id = Date.now() + count;
                  count++;
                }
  					    _self.tree.get(_category.value).get(_subcategory.value).set(_item.value, new $t(_item.value, _item.id));
                _self.setThirdPresent();
  					});
  			});
  	});
  },
  parseString: function(_text){
	_self = this,
	_category = "",
	_subcategory = "",
	_item = "",
	_caseoption = "";
    _text.split("\n")
        .each(function(_item){
           try{                    
               _caseoption = (_self.testChar(_item[0])) ? ((_self.testChar(_item[1])) ? 2 : 1): 0;
               _item = _self.removeTests(_item);        
               if(_item == '') return;
               switch(_caseoption){
                  case 0:
                     _self.tree.set(_item, new $t());
                     _category = _item;
                  break;
                  case 1:   
                    _self.tree.get(_category).set(_item, new $t());
                    _subcategory = _item;
                    _self.setSecondPresent();
                  break;
                  case 2:
                    _self.tree.get(_category).get(_subcategory).set(_item, new $t());
                    _self.setThirdPresent();
                  break;
               }
            }catch(e){            }
        });     
    //console.log(this.tree.toJSON());
  },
  setThirdPresent: function(){ this.third_level = true; },
  setSecondPresent: function(){ this.second_level = true; },  
  getCategory: function(){
      _categories = [];
      // this.tree.each(function(o){  _categories.push("<option value='"+o.value.id.replace(/,/g, '&#44;')+"'>"+o.key.replace(/,/g, '&#44;')+"</option>") });         
    this.tree.each(function(o){  _categories.push("<option value='"+o.value.id+"'>"+o.key+"</option>"); });
      return _categories.join();
  },
  getCategoryEscaped: function(){
      _categories = [];
      this.tree.each(function(o){ _categories.push("<option value='"+escapeHtml(o.value.id)+"'>"+escapeHtml(o.key)+"</option>") });         
      return _categories.join();
  }, 
  getSubcategory: function(category_key){
      _subcategories = [];
      if(this.tree.get(category_key) && this.tree.get(category_key).children)
        this.tree.get(category_key).children.each(function(o){ _subcategories.push("<option value='"+o.value.id+"'>"+o.key+"</option>") });          
      if(!_subcategories.first()) _subcategories = ["<option value='0'>"+this._blank+"</option>"];

      //console.log("subcategory: "+_subcategories);
      return _subcategories.join();   
  },
  getSubcategoryEscaped: function(category_key){
      _subcategories = [];
      if(this.tree.get(category_key) && this.tree.get(category_key).children)
        this.tree.get(category_key).children.each(function(o){ _subcategories.push("<option value='"+o.value.id+"'>"+o.key+"</option>") });          
      if(!_subcategories.first()) _subcategories = ["<option value='0'>"+this._blank+"</option>"];

      //console.log("subcategory: "+_subcategories);
      return _subcategories.join();   
  },
  getItems: function(category_key, subcategory_key){    
      _items = [];
      // console.log("category_key: "+category_key);
      // console.log("subcategory_key: "+subcategory_key);
      if(this.tree.get(category_key))
        if(this.tree.get(category_key).get(subcategory_key).children)
            this.tree.get(category_key).get(subcategory_key).children.each(function(o){ _items.push("<option value='"+o.value.id+"'>"+o.key+"</option>") });

      // console.log("ITEMS: "+_items);
      return (_items.first()) ? _items.join() : false;
  },
  getItemsEscaped: function(category_key, subcategory_key){    
      _items = [];
      // console.log("category_key: "+category_key);
      // console.log("subcategory_key: "+subcategory_key);
      if(this.tree.get(category_key))
        if(this.tree.get(category_key).get(subcategory_key).children)
            this.tree.get(category_key).get(subcategory_key).children.each(function(o){ _items.push("<option value='"+escapeHtml(o.value.id)+"'>"+escapeHtml(o.key)+"</option>") });

      // console.log("ITEMS: "+_items);
      return (_items.first()) ? _items.join() : false;
  },

  getCategoryList: function(){
      _categories = [];
      this.tree.each(function(o){  _categories.push(o.key) });
      return _categories;
  },

  getSubcategoryList: function(category_key){
      //console.log(this.tree.get(category_key).children.toJSON());
      return ((category_key && category_key != "-1") ? this.tree.get(category_key).children : $H()) || $H()
  },
  
  getSubcategoryListWithNone: function(category_key){
      return ( category_key != "-1" ? this.tree.get(category_key).children : $H()) || $H()
  },

  getItemsList: function(category_key, subcategory_key){          
      //console.log(this.tree.get(category_key) + "  " + subcategory_key);
      return ((subcategory_key && subcategory_key != "-1" && this.tree.get(category_key)) ? this.tree.get(category_key).get(subcategory_key).children : $H()) || $H();
  },
  
  getItemsListWithNone: function(category_key, subcategory_key){          
      return ((subcategory_key != "-1" && this.tree.get(category_key)!='-1') ? 
              ( subcategory_key ? this.tree.get(category_key).get(subcategory_key).children : $H()) : $H() ) || $H();
  },
  converttoArray: function(){
    return this.revamped ? this.toObjectArray() : this.toArray();
  },
  toString: function(){
      _self = this, _treeString = "";
      _self.tree.each(function(_category){
         _treeString += unescapeHtml(_category.key) + "\n";
         _category.value.children.each(function(_subcategory){
            _treeString += "\t" + unescapeHtml(_subcategory.key) + "\n";  
            _subcategory.value.children.each(function(_item){
                _treeString += "\t\t" + unescapeHtml(_item.key) + "\n";      
            });
         });
      });                              
      return _treeString;
  }, 
  toArray: function(){
        _self = this, _category_array = [];
        _self.tree.each(function(_category){  
            var _subcategory_array = [];
            _category.value.children.each(function(_subcategory){  
                var _item_array = [];
                _subcategory.value.children.each(function(_item){
                   _item_array.push([escapeHtml(_item.key), escapeHtml(_item.value.id)]);  
               });                                              
               _subcategory_array.push((_item_array.length) ? [escapeHtml(_subcategory.key), escapeHtml(_subcategory.value.id), _item_array] : [escapeHtml(_subcategory.key), (_subcategory.value.id)]);               
            });               
           _category_array.push((_subcategory_array.length) ? [escapeHtml(_category.key), escapeHtml(_category.value.id), _subcategory_array] : [escapeHtml(_category.key), escapeHtml(_category.value.id)]);
        });          
        return _category_array;      
  },
  toObjectArray: function(tree){
    tree = tree || this.tree;
    var _self = this, object_array = [];
    tree.each(function(item){ 
      if(item.value.children){
        object_array.push({ 
          value: escapeHtml(item.key), 
          id: item.value.listId, 
          name: escapeHtml(item.key),
          destroyed: item.destroyed ? item.destroyed : false, 
          choices: _self.toObjectArray(item.value.children)
        });
      }
    });          
    return object_array;      
  }
});

(function($) {
    "use strict";

    var ConstructRules = function($this, options){
        var option = false;
        this.$currentElement = $this;
        this.options = $.extend({}, $.fn.constructRules.defaults, options, $this.data());
        this.$scriptElement =  $(this.options.renderTemplate)
        this.inputArea = {};
        this.inputAttrName = {};
        this.default_data = [];
        this.default_data_key = {};
        this.dropdown1_validator = options.fdTypeValidator;
        this.dropdown2_validator = options.crmTypeValidator;
        this.maximumSize = options.maximumSelectionSizeContact;
        this.customModule = options.customModule;
        this.customMaxSize = options.customMaxSize;
        this.customSize = 0;
        this.selectedCustomSize = [];
        this.data_type = [];
        this.init();
    }
 
    ConstructRules.prototype = {

        init: function(){
            var self = this;
            this.default_data = this.$scriptElement.data('defaultValue');
            this.$scriptElement = $('<div class="construct_rule"/>',{ "data-default-value" : this.$scriptElement.data('defaultValue')}).html(this.$scriptElement.html());
            var $currentChilds = this.$scriptElement.children(); 
            var elementList = [];

            $currentChilds.each(function(){

                var options = $(this).children('option');
                var type = $(this).attr('rel');

                self.data_type.push(type);
                var arr = $.grep(self.data_type, function( a ) {
                  return a == type;
                });

                var element_count = arr.size();

                self.inputArea[$(this).attr('rel')] ? "" : self.inputArea[$(this).attr('rel')] = {};

                var options_data = options.map(function(index, item){
                    if(self.customModule === "sync"){
                        return {
                            text: item.innerHTML,
                            id: item.value,
                            type: $(item).data('fieldType'),
                            disabled: false,
                            customSize: $(item).data('customSize')
                        };
                    } else {
                        return {
                            text: item.innerHTML,
                            id: item.value,
                            disabled: false
                        };
                    } 
                });
                
                self.inputArea[$(this).attr('rel')][$(this).attr('rel') + "_" + element_count] = options_data;
                self.inputAttrName[$(this).attr('rel') + "_" + element_count] = $(this).attr('name');
                self.default_data_key[$(this).attr('rel') + "_" + element_count] = $(this).data('referKey');
            });
                
            this.constructWrapper(); 

            if(this.default_data != null && this.default_data.length > 0){
                this.updateSelect2();
            } else {
                var $row = this.appendNewRule();
                this.constructSelect2($row);
            }

            this.checkAddButtonForDropdown("Init");
        },
        constructWrapper: function(){
            var $temp_div = $('<div />');
            var $wrapper = $("<div>", { class: 'rules_list_wrapper' });
            var $addElement = $('<div>', { class:"add_menu_wrapper" })
                $addElement.append('<div class="add_new_list list" class="active"><div class="list-data"><a class="add_img list-icon"></a></div> <div class="list-data pt14 pb14"><span class="add_list"> Add New </span></div></div>'); 
                $addElement.append('<div class="empty_list_alert list"> <div class="list-data"></div> <div class="list-data"> <p class="m10 muted"> Cannot add any more fields </p></div></div>') 
                $temp_div.append('<div class="tabel-thead"></div>')
                        .append($wrapper).append($addElement);          
            this.$currentElement.html($temp_div.html());

            this.appendTableHeader();
            this.$currentElement.find('.add_new_list').on('click', $.proxy(this.addNewRow, this))
        },
        appendTableHeader: function(){
            var rule_data = this.$scriptElement.children();
            if($(rule_data[0]).data('headerLabel') != undefined && $(rule_data[0]).data('headerLabel') != ''){
                var $tr = $('<div class="list" />')
                $tr.append( $('<div class="list-data">'));
                $.each(rule_data, function(index, data){    
                    $tr.append('<div class="list-data"> <p class="header-txt">' + $(this).data("headerLabel") + '</p></div>')
                });

                this.$currentElement.find('.tabel-thead').html($tr);
            }
        },
        addNewRow: function(){
            var last_list = this.$currentElement.find('.list'),
                list_element  = last_list.children().children('input'),
                add_new_list = true;
            this.$currentElement.children('.rules_list_wrapper').find('.error').remove();
            var self = this;
            $.each(last_list, function(index, list_element){
                if(self.customModule == "sync"){
                    //input:not(:hidden) will only return an empty array
                    list_element = $(list_element).children().children('input:hidden');
                }else{
                    list_element = $(list_element).children().children('input:not(:hidden)')                    
                }

                $.each(list_element, function(i,element){
                    if (element.value == null || element.value == ""){
                        add_new_list = false;
                        $(element).after('<p class="error"> Field is required </p>');
                    }
                })
            })

            if(add_new_list) {
                var $list = this.appendNewRule();
                this.constructSelect2($list);
                this.checkAddButtonForDropdown("Insert");
            } 
        },
        setGenerateDataWithPrev: function($list)
        {
            var prev_element = $list.prev()

            var ele = $(prev_element).find('[rel="dropdown"]');
            var self = this;

            $.each(ele,function(key, hidden_input){
                 self.setGeneratedData(hidden_input)
            })
        },
        appendNewRule: function(){

            var count = this.$currentElement.children('.rules_list_wrapper').children().size();
            var self = this;

            var $list = $('<div class="list"/>');
                $list.append('<div class="list-data"><a class="remove_list list-icon bind-remove-icon"></a>');

            $.each(this.inputArea, function(key, value){
                $.each(value, function(list, options){
                    if(key == 'input_text'){
                        $list.append($('<div class="list-data">').html($('<input>',{ name: self.inputAttrName[list] ,type: 'text', width : '200px', class: list, 'data-current-type': list, rel: key, "data-refer-key": self.default_data_key[list]})))
                    } else {
                        $list.append($('<div class="list-data">').html($('<input>',{ name: self.inputAttrName[list] ,type: 'hidden', width : '200px', class: list, 'data-current-type': list, rel: key, "data-refer-key": self.default_data_key[list]})))
                    }
                 })
            })
            
            // $list.append($control);
            this.$currentElement.children('.rules_list_wrapper').append($list);
            this.bindRemove();
            return $list;
        },
        checkAddButtonForDropdown: function(action){
            var self = this;

            if(this.inputArea['dropdown'] != undefined && this.inputArea['dropdown'] != "") {
                $.each(this.inputArea['dropdown'], function(key, object){
                    var select2_count = self.$currentElement.children('.rules_list_wrapper').children().size();
                    var size = 0;
                    if(self.customModule === "sync"){
                        $.each(object,function(index, item){
                            if(item["disabled"] == true){
                                size = size + 1;
                            }
                        });
                    }
                    if(action === "Insert")
                        size++;
                    if(object.size() == select2_count || (self.customModule === "sync" && (size == self.maximumSize || object.size() == size))){
                        self.$currentElement.children('.add_menu_wrapper').find('.add_new_list').hide();
                        self.$currentElement.children('.add_menu_wrapper').find('.empty_list_alert').css('display','table-row');
                        return false;
                    } else {
                        self.$currentElement.children('.add_menu_wrapper').find('.add_new_list').show();
                        self.$currentElement.children('.add_menu_wrapper').find('.empty_list_alert').hide();
                    }
                })
            }
        },
        bindRemove: function(){
            this.$currentElement.find('.bind-remove-icon').off('click');
            this.$currentElement.find('.bind-remove-icon').on('click', $.proxy(this.removeList, this));
        },
        getValue: function(element){
            var data = [];

            $.each(this.inputArea[$(element).attr('rel')][$(element).data('currentType')], function(key, object){
                if(object['disabled'] == false){ 
                    data.push(object);
                }
            })

            return data;
        },
        setDisable: function(value, object){
            $.each(this.inputArea[$(value).attr('rel')][$(value).data('currentType')], function(key, val){
                if(val['id'] == object['id']){ 
                    val.disabled = false;
                }
            })
            
            this.changePreviouesData(value)
        },
        changePreviouesData: function(element){
            var list = this.$currentElement.children('.rules_list_wrapper').first().children().not('.overlay');
            var self = this;
            var element_data = $(element).select2('data');

            function refresh_all_data(list) {

                var hidden_input = $(list).find('input.' + $(element).data('currentType'))

                if (!list.next().get(0)) {
                    if(self.customModule == "sync"){
                        self.bindSyncSelect2(hidden_input,element);
                    }else{
                        self.bindSelect2(hidden_input,element);
                    }
                    return false;
                }
                if(self.customModule == "sync"){
                    self.bindSyncSelect2(hidden_input,element);
                }else{
                    self.bindSelect2(hidden_input,element);
                }
                
                return refresh_all_data(list.next())
            }

            refresh_all_data(list.first())

        },
        onChangeSelect2: function(element){

            jQuery(element).next('.error').remove();
            var select2_data = $(element).select2('data');
            var old_value = $(element).data('oldValue');
            var object = this.inputArea[$(element).attr('rel')][$(element).data('current-type')];

            if(select2_data.customSize) {
                this.customSize = this.customSize + 1;
                this.selectedCustomSize.push(select2_data['id']);
            }

            if(old_value !== undefined){
                if(old_value['id'] != select2_data['id'] && old_value.customSize) {
                    this.includeCustomFields(object, old_value["id"]);
                }
            }

            for(var i = 0; i < object.length; i++) {
                if(object[i]['id'] == select2_data['id']){
                    object[i].disabled = true;
                    $(element).data('oldValue', object);
                }
                if(this.customMaxSize == this.customSize && object[i].customSize) {
                    object[i].disabled = true;
                }
                if(old_value !== undefined && object[i]['id'] == old_value['id'] && select2_data['id'] != old_value['id']){
                    object[i]['disabled'] = false;
                }
            }

            this.changePreviouesData(element);
            if(this.customModule === "sync" && this.customMaxSize == this.customSize ){
                this.checkAddButtonForDropdown("Insert");
            }
        },
        includeCustomFields: function(object, id){
            this.customSize = this.customSize - 1;
            var index = this.selectedCustomSize.indexOf(id)
            this.selectedCustomSize.splice(index,1);
            if(this.customSize == this.customMaxSize-1) {
                for(var i = 0; i < object.length; i++) {
                    if(this.selectedCustomSize.indexOf(object[i]['id']) == -1 && object[i].customSize){
                        object[i]['disabled'] = false;
                    }
                }
            }
        },
        constructSelect2: function($list){
            var self = this;
            var hidden_input = $($list).find('input');
            $.each(hidden_input, function(key, value){

                if($(value).attr('rel') == 'dropdown') {
                    var select2_data = self.getValue(value);

                    // Initialize select2 for dropdown and bind change event
                    $(value).select2({
                        data: select2_data,
                        allowClear : false,
                        placeholder: "Select",
                    }).off().on('change', function(ev){
                        self.onChangeSelect2(this);

                    })

                } else if($(value).attr('rel') == 'multi_select'){
                    // Initilize select2 for multi select
                    var select2_data = self.inputArea[$(value).attr('rel')][$(value).data('currentType')];

                    $(value).select2({
                        data : select2_data,
                        multiple: true,
                        allowClear : true,
                    });
                } else if($(value).attr('rel') == 'input_text' || $(value).attr('rel') == 'hidden_text'){

                }

            })
        },
        bindSelect2: function(hidden_input, element){
            var self = this;
            var select2_data = $(hidden_input).select2('data');
            var array = self.getValue(element);

            $(hidden_input).select2("destroy");
            $(hidden_input).select2({
                data: array,
                allowClear : true,
                initSelection: function (element, callback) {

                    callback(select2_data);
                }
            }).off().on('change', function(ev){

                self.onChangeSelect2(this);
            }).data('oldValue', select2_data);
 
            $(hidden_input).select2('val', select2_data)
        },
        bindSyncSelect2: function(hidden_input, element){
            var self = this;
            var select2_data = $(hidden_input).select2('data');
            var hidden_sibling_input = $(hidden_input).parent().siblings().find('input[rel]');
            var select2_sibling_data = hidden_sibling_input.select2('data');
            if(select2_sibling_data && select2_sibling_data['type']){
                var array = self.getValueWithType(element, select2_sibling_data['type']);
            }
            else{
                var array = self.getValue(element);        
            }            

            $(hidden_input).select2("destroy");
            
            if(select2_data){
                $(hidden_input).select2({
                    data: array,
                    allowClear : true,
                    initSelection: function (element, callback) {

                        callback(select2_data);
                    }
                }).off().on('change', function(ev){
                    self.onChangeSelect2(this);
                }).data('oldValue', select2_data);

                $(hidden_input).select2('val', select2_data);
                self.bindSiblingSelect2(hidden_sibling_input, select2_data['type']);
            }else{
                $(hidden_input).select2({
                    data: array,
                    allowClear : false,
                    placeholder: "Select",
                }).off().on('change', function(ev){
                    self.onChangeSelect2(this);
                }).data('oldValue', array[0]);
            }
        },
        bindSiblingSelect2: function(hidden_input, type){
            var self = this;
            var select2_data = $(hidden_input).select2('data');

            if(select2_data == null){
                var select2_data = self.getValueWithType(hidden_input, type); 
                var placeholder_value = "Select";
                if(select2_data.length== 0){
                    placeholder_value = "No Matching data..."
                }
                $(hidden_input).select2({
                    data: select2_data,
                    allowClear : false,
                    placeholder: placeholder_value,
                }).off().on('change', function(ev){
                    self.onChangeSelect2(this);
                }).data('oldValue', select2_data[0]);
            }
            else{
                if(select2_data['type']){
                    var array = self.getValueWithType(hidden_input, type); 
                    // array.push(select2_data);
                    $(hidden_input).select2("destroy");
                    $(hidden_input).select2({
                        data: array,
                        allowClear : true,
                        initSelection: function (element, callback) {
                            callback(select2_data);
                        }
                    }).off().on('change', function(ev){
                        self.onChangeSelect2(this);
                    }).data('oldValue', select2_data);
                }
            }
        },
        removeList: function(ev){
            var self = this;
            var list_element = $(ev.target).parent().siblings().find('[rel="dropdown"]');
            if(this.customModule == "sync"){
                list_element.each(function(index, element){
                    var select2_data = $(element).select2('data');
                    if(select2_data != null){
                        if(select2_data.customSize){
                            var object = self.inputArea[$(element).attr('rel')][$(element).data('current-type')];
                            self.includeCustomFields(object, select2_data['id']);
                        }
                        self.setDisable(element,select2_data);
                    }
                })
            }else{
                if(list_element.val() != ""){
                    list_element.each(function(index, element){
                        var select2_data = $(element).select2('data');
                        self.setDisable(element,select2_data)
                    })
                }
            }
            $(ev.target).parent().parent().remove();
            self.$currentElement.children('.add_menu_wrapper').find('.prev_empty_notify').removeClass('inline');
            this.checkAddButtonForDropdown("Delete");
        },
        updateSelect2: function(){
            var self = this;
            var selected_value = {};
            var field = self.options.disableField;
            var disable_field = field.split(',');

             $.each(this.default_data, function(index, object){
                var $list = self.appendNewRule();

                $.each(object, function(key, value){

                    var $input = $list.find('[data-refer-key=' + key + ']'),
                        refer_key = $input.data('referKey'),
                        rel = $input.attr('rel');            
                    if($.inArray(object[refer_key], disable_field ) != -1){
                        $list.addClass('overlay');
                        $list.find('.bind-remove-icon').off();
                        $list.find('.remove_list').removeClass('bind-remove-icon');
                    }

                    if( rel == 'dropdown'){

                        $.each(self.inputArea[$input.attr('rel')][$input.data('currentType')],function(i, v){
                            if(v.id == value){
                                v.disabled = true;
                                selected_value = v;
                            }
                        })

                        var select2_data = self.getValue($input[0])
                         // Initialize select2 for dropdown and bind change event
                        $input.select2({
                            data: select2_data,
                            allowClear : false,
                            initSelection: function (element, callback) {
                                callback(selected_value);
                            }
                        }).on('change', function(ev){

                             self.onChangeSelect2(this);
                        }).data('oldValue', selected_value);

                        $input.select2('val', selected_value).trigger('change');

                    } else if( rel == 'multi_select'){
                        // Initilize select2 for multi select
                        var select2_data = self.getValue($input[0]);
                        var init_select2 = [];
                        var array_value = value.split(",");

                        $.each(array_value,function(i,val){
                            init_select2.push({ id: val, text:val, disabled: false })
                        })

                        $input.select2({    
                            data : select2_data,
                            multiple: true,
                            allowClear : true,
                            initSelection: function (element, callback) {
                                callback(init_select2);
                            }
                        });

                        $input.select2('val', init_select2).trigger('change')

                    } else if(rel == 'input_text' || rel == 'hidden_text'){

                        $input.val(value);
                    }
                })    
            })
            
            var $overlay = self.$currentElement.children('.rules_list_wrapper').children('.list.overlay');
            if($overlay.get(0)){
                $overlay.find('[type="hidden"]').select2('disable');
                $overlay.find('[type="text"]').attr('disabled', 'disabled');
            }
            this.bindRemove();
        },
        getValueWithType: function(element, type){
            var data = [];
            var validator = {};
            if($(element).data('currentType') == 'dropdown_1'){
                validator= this.dropdown1_validator;
            }
            else{
                validator= this.dropdown2_validator;
            }

            var val_keys = Object.keys(validator);
            var validDataTypes = val_keys.filter(function(valkey){
                return validator[valkey].indexOf(type) !== -1;
                
            })

            $.each(this.inputArea[$(element).attr('rel')][$(element).data('currentType')], function(key, object){
                if(object['disabled'] == false && validDataTypes.indexOf(object['type']) != -1){ 
                    data.push(object);
                }
            })

            return data;
        }
    }

    $.fn.constructRules = function(option){
        return this.each(function() {
            var $this = $(this),
            data      = $this.data("constructRules"),   
            options   = typeof option == "object" && option
            if (!data) $this.data("constructRules", (data = new ConstructRules($this,options)))
            if (typeof option == "string") data[option]()   
        });
    }

    $.fn.constructRules.defaults = {
        createRuleData : [],
        rule_value : [],
        disableField : '',
        renderTemplate : '', // ----- variable only for template rendering. Have to give template class
        customMaxSize : 0
    }
}(jQuery));
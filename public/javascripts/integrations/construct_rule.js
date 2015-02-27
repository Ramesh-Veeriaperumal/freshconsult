(function($) {

    var ConstructRules = function($this){
        this.$currentElement = $this;
        this.inputArea = {};
        this.inputAttrName = {};
        this.default_data = [];
        this.default_data_key = {};
        this.init();
    }

    ConstructRules.prototype = {

        init: function(){
            var $currentChilds = this.$currentElement.children(); 
            this.default_data = this.$currentElement.data('defaultValue');

            var self = this;
            var elementList = [];

            $currentChilds.each(function(){
                var options = $(this).children('option');
                var options_data = [];
                var has_same_element_count = self.$currentElement.find("[rel=" + $(this).attr('rel') + "]").size();

                (self.inputArea[$(this).attr('rel')]) ? "" : self.inputArea[$(this).attr('rel')] = {};

                for (var i = options.length - 1; i >= 0; i--) {
                    options_data.push({ 'text' : options[i].innerHTML , 'id' : options[i].value, disabled: false });
                };
                
                self.inputArea[$(this).attr('rel')][$(this).attr('rel') + "_" + has_same_element_count] = options_data;
                self.inputAttrName[$(this).attr('rel') + "_" + has_same_element_count] = $(this).attr('name');
                self.default_data_key[$(this).attr('rel') + "_" + has_same_element_count] = $(this).data('referKey');

                $(this).remove();
            });

            this.constructWrapper(); 

            if(this.default_data != null && this.default_data.length > 0){
                this.updateSelect2();
            } else {
                var $list = this.appendNewRule();
                this.constructSelect2($list);
            }

            this.checkAddButton();
        },
        constructWrapper: function(){
            var $temp_div = $('<div />');
            var $wrapper = $("<div>", { class: 'rules_list_wrapper' });
            var $addElement = $('<div>', { class:"add_menu_wrapper" })
                $addElement.append('<div class="add_new_list" class="active"><img alt="Add new" class="add_img" src="/images/add.png"> <span class="add_list"> Add New </span></div>'); 
                $addElement.append('<div class="empty_list_alert"> No value to select </div>') 
                $temp_div.append($wrapper).append($addElement);          
            this.$currentElement.html($temp_div.html());

            this.$currentElement.find('.add_new_list').on('click', $.proxy(this.addNewRow, this))
        },
        addNewRow: function(){
            var $list = this.appendNewRule();
            this.constructSelect2($list);
            this.checkAddButton();
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
                $list.append('<img class="delete remove_list" src="/images/delete.png">');
            var $control = $('<div class="control">');

            $.each(this.inputArea, function(key, value){
                $.each(value, function(list, options){
                    if(key == 'input_text'){
                        $control.append($('<input>',{ name: self.inputAttrName[list] ,type: 'text', width : '200px', class: list, rel: key, "data-refer-key": self.default_data_key[list]}))
                    } else {
                        $control.append($('<input>',{ name: self.inputAttrName[list] ,type: 'hidden', width : '200px', class: list, rel: key, "data-refer-key": self.default_data_key[list]}))
                    }
                   
                })
            })
            
            $list.append($control);

            this.$currentElement.children('.rules_list_wrapper').append($list);
            this.bindRemove();

            return $list;
        },
        checkAddButton: function(){
            var self = this;
            $.each(this.inputArea['dropdown'], function(key, object){
                if(object.size() == self.$currentElement.children().first().children().size()){
                    self.$currentElement.children('.add_menu_wrapper').find('.add_new_list').hide();
                    self.$currentElement.children('.add_menu_wrapper').find('.empty_list_alert').show();
                    return false;
                } else {
                    self.$currentElement.children('.add_menu_wrapper').find('.add_new_list').show();
                    self.$currentElement.children('.add_menu_wrapper').find('.empty_list_alert').hide();
                }
            })
        },
        bindRemove: function(){
            this.$currentElement.find('.remove_list').off('click');
            this.$currentElement.find('.remove_list').on('click', $.proxy(this.removeList, this));
        },
        getValue: function(element){
            var data = [];

            $.each(this.inputArea[$(element).attr('rel')][$(element).attr('class')], function(key, object){
                if(object['disabled'] == false){ 
                    data.push(object);
                }
            })

            return data;
        },
        setDisable: function(value, object){
            $.each(this.inputArea[$(value).attr('rel')][$(value).attr('class')], function(key, val){
                if(val['id'] == object['id']){ 
                    val.disabled = false;
                }
            })
            
            this.changePreviouesData(value)
        },
        changePreviouesData: function(element){
            var list = this.$currentElement.children().first().children();
            var self = this;
            var element_data = $(element).select2('data');

            function refresh_all_data(list) {

                var hidden_input = $(list).find('input.' + $(element).attr('class'))

                if (!list.next().get(0)) {
                    self.bindSelect2(hidden_input,element);
                    return false;
                }
                self.bindSelect2(hidden_input,element);
                
                return refresh_all_data(list.next())
            }

            refresh_all_data(list.first())

        },
        onChangeSelect2: function(element){

            var select2_data = $(element).select2('data');
            var old_value = $(element).data('oldValue');

            $.each(this.inputArea[$(element).attr('rel')][$(element).attr('class')], function(key, val){
                if(val['id'] == select2_data['id']){ 
                    val.disabled = true;
                    $(element).data('oldValue', val);
                }

                if(val['id'] == old_value['id'] && select2_data['id'] != old_value['id']){
                    val.disabled = false;
                }
            })

            this.changePreviouesData(element);

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
                        allowClear : true,
                        initSelection: function (element, callback) {

                            callback(select2_data[0]);
                        }
                    }).on('change', function(ev){
                        self.onChangeSelect2(this);

                    }).data('oldValue', select2_data[0]);

                    $(value).select2('val', select2_data[0]).trigger('change');

                } else if($(value).attr('rel') == 'multi_select'){
                    // Initilize select2 for multi select
                    var select2_data = self.inputArea[$(value).attr('rel')][$(value).attr('class')];

                    $(value).select2({
                        data : select2_data,
                        multiple: true,
                        allowClear : true,
                    });
                } else if($(value).attr('rel') == 'input_text'){

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
        removeList: function(ev){
            var self = this;

            $(ev.target).siblings().find('[rel="dropdown"]').each(function(index, element){
                var select2_data = $(element).select2('data');
                self.setDisable(element,select2_data)
            })

            $(ev.target).parent().remove();
            this.checkAddButton();
        },
        updateSelect2: function(){
            var self = this;
            var selected_value = {};

             $.each(this.default_data, function(index, object){
                var $list = self.appendNewRule();

                $.each(object, function(key, value){

                    var $input = $list.find('[data-refer-key=' + key + ']');

                    if($input.attr('rel') == 'dropdown'){

                        $.each(self.inputArea[$input.attr('rel')][$input.attr('class')],function(i, v){
                            if(v.id == value){
                                v.disabled = true;
                                selected_value = v;
                            }
                        })

                        var select2_data = self.getValue($input[0])
                         // Initialize select2 for dropdown and bind change event
                        $input.select2({
                            data: select2_data,
                            allowClear : true,
                            initSelection: function (element, callback) {
                                callback(selected_value);
                            }
                        }).on('change', function(ev){

                             self.onChangeSelect2(this);
                        }).data('oldValue', selected_value);

                        $input.select2('val', selected_value).trigger('change');

                    } else if($input.attr('rel') == 'multi_select'){
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

                    } else if($input.attr('rel') == 'input_text'){
                        $input.val(value);
                    }
                })    
            })

            this.bindRemove();
        }
    }

    $.fn.constructRules = function(){
        return this.each(function() {
            var $this = $(this);
            var construct_rule = new ConstructRules($this);
        });
    }
}(jQuery));
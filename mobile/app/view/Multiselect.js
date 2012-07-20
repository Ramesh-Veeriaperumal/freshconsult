Ext.define('Freshdesk.view.MultiSelect', {
    extend: 'Ext.field.Select',
    alias : 'widget.multiselectfield',
    xtype : 'multiselectfield',
    usePicker : false,  //force list panel, not picker

    getTabletPicker: function() {  //override with modified function
        var config = this.getDefaultTabletPickerConfig();
        if (!this.listPanel) {
            this.listPanel = Ext.create('Ext.Container', Ext.apply({
                cls: Ext.baseCSSPrefix + 'select-overlay',
                layout: 'fit',
                fullScreen:true,
                zIndex:2,
                width:'100%',
                height:'100%',
                showAnimation: {
                        type:'slide',
                        direction:'up',
                        easing:'ease-out'
                },
                hideAnimation: {
                        type:'slide',
                        direction:'down',
                        easing:'ease-out'
                },
                items: [
                    {
                        xtype: 'list',
                        mode: 'MULTI', //set list to multi-select mode
                        store: this.getStore(),
                        itemTpl: '<span class="bullet"></span>&nbsp;{' + this.getDisplayField() + '}',
                        listeners: {
                            select : this.onListSelect,
                            itemtap  : this.onListTap,
                            hide : this.onListHide, //new listener
                            scope  : this
                        }
                    },
                    {
                        xtype:'titlebar',
                        title:'Notify Agents',
                        ui:'header',
                        docked:'top',
                        items:[
                            {
                                xtype:'button',
                                ui:'plain headerBtn',
                                iconMask:true,
                                align:'left',
                                text:'Cancel',
                                handler:function(){
                                    this.listPanel.hide();
                                },
                                scope:this
                            },
                            {
                                xtype:'button',
                                ui:'plain headerBtn',
                                iconMask:true,
                                align:'right',
                                text:'Apply',
                                handler:this.onButtonTap,
                                scope:this
                            }
                        ]
                    }
                    ]
            }, config));
            Ext.Viewport.add([this.listPanel])
        }
        return this.listPanel;
    },
    
    applyValue: function(value) {  //override with modified function
        var record = value,
            index;
        this.getOptions();
        if (!(value instanceof Ext.data.Model)) {
            index = this.getStore().find(this.getValueField(), value, null, null, null, true);

            if (index == -1) {
                index = this.getStore().find(this.getDisplayField(), value, null, null, null, true);
            }
            //We do not want to get record from store //record = this.getStore().getAt(index);
             this.element.dom.lastChild.firstChild.firstChild.value = value; //display csv string in field when value applied
        }
        return record;
    },

    updateValue: function(newValue, oldValue) {  //override with modified function
        this.previousRecord = oldValue;
        this.record = newValue;
        // String does not have methods //this.callParent([newValue ? newValue.get(this.getDisplayField()) : '']);
        this.fireEvent('change', this, newValue, oldValue);
    },

    getValue: function() {  //override with modified function
        var record = this.record;
        return (record) // Use literal string value of field // ? record.get(this.getValueField()) : null;
    },

    showPicker: function() {  //override with modified function
        //check if the store is empty, if it is, return
        if (this.getStore().getCount() === 0) {
            return;
        }
        if (this.getReadOnly()) {
            return;
        }
        this.isFocused = true;
        //hide the keyboard
        //the causes https://sencha.jira.com/browse/TOUCH-1679
        // Ext.Viewport.hideKeyboard();
        if (this.getUsePicker()) {
            var picker = this.getPhonePicker(),
                name   = this.getName(),
                value  = {};

            value[name] = this.record.get(this.getValueField());
            picker.setValue(value);
            if (!picker.getParent()) {
                Ext.Viewport.add(picker);
            }
            picker.show();
        } else { //reworked code to split csv string into array and select correct list items
            var listPanel = this.getTabletPicker(),
                list = listPanel.down('list'),
                store = list.getStore(),
                itemStringArray = new Array(),
                values = this.getSelectedValue().split(','),
                v = 0,
                vNum = values.length;
            if (!listPanel.getParent()) {
                Ext.Viewport.add(listPanel);
            }
            for (; v < vNum; v++) {
                itemStringArray.push(values[v]);
            }
            v = 0;
            for (; v < vNum; v++) {
                var record = store.findRecord(this.getDisplayField(), itemStringArray[v], 0, true, false, false );
                list.select(record, true, false);
            }
            listPanel.show();
            if(!itemStringArray[0]) {
                listPanel.down('list').deselectAll();
            }
            listPanel.down('list').show();
        }
    },
    getSelectedValue : function(){
        if(typeof this.getValue() === 'string'){
            return this.getValue();
        }
        return '';
    },

    onListSelect: function(item, record) {  //override with empty function
    },

    onListTap: function() {  //override with empty function
    },

    onButtonTap: function() {
        this.setValue('');
        this.listPanel.down('list').hide(); //force list hide event
        this.listPanel.hide();
    },

    onListHide: function(cmp, opts) {

        var me = this,
            recordArray = this.listPanel.down('list').selected.items,
            itemStringArray = new Array(),
            v = 0,
            vNum = recordArray.length;
        for (; v < vNum; v++) {
            var value = this.getDisplayField(),
                valArr = value.split('.'),
                j=0,
                val = recordArray[v].data;
            for(; j< valArr.length; j++) {
                val = val[valArr[j]] ;
            }
            itemStringArray.push(val);
        }
        if (itemStringArray.length > 0) {
            me.setValue(itemStringArray.join(','));
            this.listPanel.down('list').deselectAll();
        } else {
            me.setValue('');
        }
    }
});
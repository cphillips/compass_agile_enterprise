Ext.define("Compass.ErpApp.Organizer.DefaultMenuTreeStore",{
    extend:"Ext.data.TreeStore",
    alias:'widget.defaultmenutreestore',

    constructor: function(config){
        var fields = [{
            name:'text'
        },{
            name:'leaf'
        },{
            name:'iconCls'
        },{
            name:'applicationCardId'
        }];
    
        if(config['additionalFields']){
            fields = fields.concat(config['additionalFields']);
        }

        config = Ext.apply({
            autoLoad:true,
            proxy: {
                type: 'ajax',
                url: config['url']
            },
            root: {
                text: config['rootText'],
                expanded: true,
                iconCls:config['rootIconCls']
            },
            fields:fields
        }, config);

        this.callParent([config]);
    }
});


Ext.define("Compass.ErpApp.Organizer.DefaultMenuTreePanel",{
    extend:"Ext.tree.Panel",
    alias:'widget.defaultmenutree',
    treePanel: null,
    
    constructor: function(config) {
        var setActiveCenterItemFn = function(view, record, item, index, e){
            if (record.data.applicationCardId) {
                Compass.ErpApp.Organizer.Layout.setActiveCenterItem(record.data.applicationCardId);
            }
        };

        if(!config['listeners'])
            config['listeners'] = {}; 
        config.listeners['itemclick'] = setActiveCenterItemFn;

        config = Ext.apply({
            animate:true,
            autoScroll:false,
            frame:false,
            containerScroll:true,
            height:300,
            border:false
        }, config);
        
        this.callParent([config]);
    }
});




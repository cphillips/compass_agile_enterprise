// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require_self

Ext.ns('Compass.ErpApp.Mobile');
Compass.ErpApp.Mobile.Applications = {};
Compass.ErpApp.Mobile.Base = {};
Compass.ErpApp.Mobile.Utility = {};

Ext.application({
    name: 'compass_ae_mobile',
    useLoadMask: true,

    launch: function () {
        var items = [
            {
                itemId: 'home',
                xtype: 'tabpanel',
                tabBarPosition: 'bottom',
                items: [
                    {
                        itemId:'applications',
                        xtype: 'container',
                        cls: 'applications-background',
                        title: 'Applications',
                        iconCls: 'home',
                        layout: 'fit',
                        items: {
                            xtype: 'dataview',
                            itemSelector: 'div.thumb-wrap',
                            store: {
                                fields: ['iconCls', 'name', 'itemId'],
                                data: mobileApplicationsData
                            },
                            itemTpl: [
                                '<div id="applications">',
                                    '<div class="thumb-wrap">',
                                        '<div class="thumb {iconCls}">',
                                        '</div>',
                                        '<span class="title">{name}</span>',
                                    '</div>',
                                '</div>'
                            ],
                            listeners:{
                                'itemtap':function(me, index, targe, record, e, options){
                                    var itemId = record.get('itemId'),
                                        container = this.up('#mainContainer');
                                        app = container.down(itemId);
                                    container.setActiveItem(app);
                                }
                            }
                        }
                    },
                    {
                        xtype: 'button',
                        title: 'Logout',
                        iconCls: 'reply',
                        listeners:{
                            activate:function(){
                                var me = this;
                                Ext.Msg.confirm('Warning', 'Are you sure you want to logout?', function(btn){
                                    if(btn == 'yes'){
                                        window.location = '/session/sign_out?login_url=/erp_app/mobile/login';
                                    }
                                    else{
                                        me.up('tabpanel').setActiveItem('#applications');
                                    }
                                });
                            }
                        }
                    }
                ]
            }
        ];

        Ext.create("Ext.Container", {
            itemId: 'mainContainer',
            layout: 'card',
            fullscreen: true,
            items: items.concat(mobileApplications)
        });
    }
});
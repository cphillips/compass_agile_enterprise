Compass.ErpApp.Widgets.ContactUs = {
    addContactUs:function(){
        Ext.getCmp('knitkitCenterRegion').addContentToActiveCodeMirror('<%= render_widget :contact_us %>'); 
    }
}

Compass.ErpApp.Widgets.AvailableWidgets.push({
    name:'Contact Us',
    iconUrl:'/images/icons/message/message_48x48.png',
    onClick:"Compass.ErpApp.Widgets.ContactUs.addContactUs();"
});


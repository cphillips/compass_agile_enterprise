Ext.define("Compass.ErpApp.Shared.FileManagerTree", {
    extend: "Ext.tree.Panel",
    alias: 'widget.compassshared_filemanager',
    extraPostData: {},
    /*
     additional config options

     additionalContextMenuItems : any additional context menus you want to add
     allowDownload : if the user can download the file

     window.file_manager_context_menu_node
     the above variable will be set when the context menu is shown.
     */

    initComponent: function() {
        this.callParent(arguments);
        this.addEvents(
            /**triggers for security checks */
            'allowmove',
            'allowrename',
            'allowdelete',
            'allowreload',
            'allowupload',
            'allownewfile',
            'allownewfolder',
            'allowviewcontents',
            'allowdownload',
            /**
             * @event downloadfile
             * Fired before file is attempted to be download. By returing false the download action can be overriden.
             * @param {Compass.ErpApp.Shared.FileManagerTree} fileManagerTree This object
             * @param {Ext.data.model} model that represents tree node
             */
            'downloadfile',
            /**
             * @event filedeleted
             * Fired after file is deleted.
             * @param {Compass.ErpApp.Shared.FileManagerTree} fileManagerTree This object
             * @param {Ext.data.model} model that represents tree node
             */
            'filedeleted',
            /**
             * @event fileuploaded
             * Fired after file is uploaded.
             * @param {Compass.ErpApp.Shared.FileManagerTree} fileManagerTree This object
             * @param {Ext.data.model} model that represents tree node
             */
            'fileuploaded',
            /**
             * @event filereplaced
             * Fired after file is replaced.
             * @param {Compass.ErpApp.Shared.FileManagerTree} fileManagerTree This object
             * @param {Ext.data.model} model that represents tree node
             */
            'filereplaced',
            /**
             * @event contentLoaded
             * Fired after cotent is loaded from server
             * @param {Compass.ErpApp.Shared.FileManagerTree} fileManagerTree This object
             * @param {Ext.data.Model} model that represents tree node
             * @param (String) content returned from server
             */
            'contentLoaded',
            /**
             * @event contextMenu
             * Fired after content is loaded from server
             * @param {Compass.ErpApp.Shared.FileManagerTree} fileManagerTree This object
             * @param {Ext.data.model} model that represents tree node
             * @param (Event) event for this click
             */
            'handleContextMenu',
            /**
             * @event beforedrop_view
             * call through for beforedrop view event.
             */
            'beforedrop_view',
            /**
             * @event drop_view
             * call through for drop view event.
             */
            'drop_view',
            /**
             * @event showImage
             * fired when item is clicked and is an image
             */
            'showImage'
        );
    },

    selectedNode: null,

    /**
     * @cfg {boolean} handleRootContextMenu
     * True to allow root node to be handled by context menu listener
     */
    handleRootContextMenu: false,

    constructor: function(config) {
        var self = this;
        var rootConfig = {
            text: config['rootText'] || 'Files',
            id: 'root_node',
            iconCls: 'icon-content'
        };

        if (!Compass.ErpApp.Utility.isBlank(config['autoLoadRoot']) && !config['autoLoadRoot']) {
            rootConfig.children = [];
            rootConfig.autoLoad = false;
        } else {
            rootConfig.expanded = true;
            rootConfig.autoLoad = true;
        }

        var store = Ext.create('Ext.data.TreeStore', {
            sorters: [{
                property: 'text',
                direction: 'ASC'
            }],
            autoSync: false,
            folderSort: true,
            proxy: {
                method: 'GET',
                type: 'ajax',
                url: config['url'] || '/erp_app/desktop/file_manager/base/expand_directory',
                timeout: 60000
            },
            root: rootConfig,
            fields: config['fields'] || [{
                name: 'text'
            }, {
                name: 'iconCls'
            }, {
                name: 'downloadPath'
            }, {
                name: 'id'
            }, {
                name: 'leaf'
            }, {
                name: 'isSecured'
            }, {
                name: 'roles'
            }, {
                name: 'size'
            }, {
                name: 'width'
            }, {
                name: 'height'
            }, {
                name: 'url'
            }]
        });

        var defaultListeners = {
            scope: this,
            'itemmove': function(node, oldParent, newParent, index, options) {
                if (!self.fireEvent('allowmove', this)) {
                    currentUser.showInvalidAccess();
                    return false;
                }
                Ext.MessageBox.confirm('Confirm', 'Are you sure you want to move the selected file(s)?', function(btn) {
                    if (btn == 'no') {
                        store.load({
                            node: oldParent
                        });
                        store.load({
                            node: newParent
                        });
                        return false;
                    } else if (btn == 'yes') {
                        selectedNodes = self.selectedNodes; // HACK: in ExtJS 4.2.1 self.getSelectionModel().getSelection(); returns an empty array in itemmove listener so we use a temp variable self.selectedNodes
                        self.selectedNodes = [];
                        var msg = Ext.Msg.wait("Saving", "Saving move...");

                        Ext.Ajax.request({
                            url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/save_move',
                            method: 'POST',
                            params: Ext.apply({
                                parent_node: newParent.data.id,
                                selected_nodes: Ext.JSON.encode(Ext.Array.map(selectedNodes, function(node, i) {
                                    return node.data.id;
                                }))
                            }, self.extraPostData),
                            success: function(response) {
                                msg.hide();
                                var responseObj = Ext.decode(response.responseText);
                                //Ext.Msg.alert('Status', responseObj.msg);
                                if (responseObj.success) {
                                    store.load({
                                        node: newParent
                                    });
                                } else {
                                    return false;
                                }
                            },
                            failure: function(response) {
                                msg.hide();
                                var responseObj = Ext.decode(response.responseText);
                                Ext.Msg.alert('Status', responseObj.msg);
                            }
                        });
                    }
                });
            },
            'itemclick': function(view, record, item, index, e) {
                e.stopEvent();

                if (self.initialConfig.enableViewContents !== false) {
                    if (record.get('leaf')) {
                        if (!self.fireEvent('allowviewcontents', this)) {
                            currentUser.showInvalidAccess();
                            return false;
                        }

                        var fileType = record.data.id.split('.').pop();
                        if (Ext.Array.indexOf(['png', 'gif', 'jpg', 'jpeg', 'ico', 'bmp', 'tif', 'tiff'], fileType.toLowerCase()) > -1) {
                            self.fireEvent('showImage', this, record);
                        } else {
                            var msg = Ext.Msg.wait("Loading", "Retrieving contents...");
                            Ext.Ajax.request({
                                url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/get_contents',
                                method: 'POST',
                                params: {
                                    node: record.data.id
                                },
                                success: function(response) {
                                    msg.hide();
                                    self.fireEvent('contentLoaded', this, record, response.responseText);
                                },
                                failure: function() {
                                    Ext.Msg.alert('Status', 'Error loading contents');
                                    msg.hide();
                                }
                            });
                        }
                    }
                }
            },
            'itemcontextmenu': function(view, record, item, index, e) {
                e.stopEvent();
                if (record.data['contextMenuDisabled']) return false;
                if (record.data['handleContextMenu'] || (record.isRoot() && self.handleRootContextMenu)) {
                    self.fireEvent('handleContextMenu', this, record, item, index, e);
                    return false;
                }

                self.selectedNode = record;
                var menuItems = [];


                //if this is a leaf (file) allow user to view Properties
                if (record.data['leaf']) {
                    menuItems.push({
                        nodeType: 'leaf',
                        text: 'Properties',
                        iconCls: 'icon-add',
                        listeners: {
                            scope: self,
                            'click': function() {
                                var details = 'Filename: ' + record.data.text;

                                if (record.data.url) {
                                    details += '<br /> URL: ' + record.data.url;
                                }
                                if (record.data.size) {
                                    details += '<br /> Size: ' + record.data.size + ' bytes';
                                }
                                if (record.data.width) {
                                    details += '<br /> Width: ' + record.data.width + ' px';
                                }
                                if (record.data.height) {
                                    details += '<br /> Height: ' + record.data.height + ' px';
                                }
                                var messageBox = Ext.create('Ext.window.MessageBox', {
                                    style: 'white-space:nowrap;'
                                });
                                messageBox.alert('Properties', details);
                            }
                        }
                    });
                }
                // if root node don't show rename menu item
                if (record.data['id'] != 'root_node' && self.initialConfig.showRenameMenuItem !== false) {
                    menuItems.push({
                        text: 'Rename',
                        iconCls: 'icon-edit',
                        listeners: {
                            'click': function() {
                                if (!self.fireEvent('allowrename', this)) {
                                    currentUser.showInvalidAccess();
                                    return false;
                                }
                                var renameForm = {
                                    xtype: 'form',
                                    autoDestroy: true,
                                    buttonAlign: 'center',
                                    bodyStyle: 'padding: 10px 10px 0 10px;',
                                    labelWidth: 50,
                                    defaults: {
                                        anchor: '95%',
                                        allowBlank: false,
                                        msgTarget: 'side',
                                        labelWidth: 50
                                    },
                                    items: [{
                                        xtype: 'textfield',
                                        fieldLabel: 'Name',
                                        name: 'file_name',
                                        value: record.data["text"]
                                    }, {
                                        xtype: 'hidden',
                                        name: 'node',
                                        value: record.data.id
                                    }],
                                    buttons: [{
                                        text: 'Save',
                                        handler: function(btn) {
                                            var renameForm = btn.findParentByType('form');
                                            if (renameForm.getForm().isValid()) {

                                                var params = Ext.apply(renameForm.getValues(), self.extraPostData);

                                                var msg = Ext.Msg.wait("Loading", "Renaming file...");
                                                Ext.Ajax.request({
                                                    url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/rename_file',
                                                    method: 'POST',
                                                    params: params,
                                                    success: function(response) {
                                                        msg.close();
                                                        var responseObj = Ext.decode(response.responseText);

                                                        if (responseObj.success) {
                                                            delete self.extraPostData.node;
                                                            store.load({
                                                                node: record.parentNode,
                                                                params: params
                                                            });
                                                            var window = renameForm.findParentByType('window');
                                                            window.close();
                                                        } else {
                                                            Ext.Msg.alert("Error", responseObj.error);
                                                        }
                                                    },
                                                    failure: function(response) {
                                                        msg.close();
                                                        var responseObj = Ext.decode(response.responseText);
                                                        msg.hide();
                                                        Ext.Msg.alert('Status', responseObj.msg);
                                                    }
                                                });
                                            }
                                        }
                                    }, {
                                        text: 'Reset',
                                        handler: function(btn) {
                                            var renameForm = btn.findParentByType('form');
                                            renameForm.getForm().reset();
                                        }
                                    }]
                                };

                                var type = '';
                                if (record.data["leaf"]) {
                                    type = 'file';
                                } else {
                                    type = 'directory';
                                }

                                var renameWindow = Ext.create('Ext.window.Window', {
                                    title: 'Rename ' + type,
                                    layout: 'fit',
                                    width: 500,
                                    height: 120,
                                    items: [
                                        renameForm
                                    ]
                                });

                                renameWindow.show();
                            }
                        }
                    });
                }

                // if root node don't show delete menu item
                if (record.data['id'] != 'root_node') {
                    menuItems.push({
                        text: 'Delete',
                        iconCls: 'icon-delete',
                        listeners: {
                            scope: this,
                            'click': function() {
                                selectedNodes = self.getSelectionModel().getSelection();

                                if (!self.fireEvent('allowdelete', this)) {
                                    currentUser.showInvalidAccess();
                                    return false;
                                }
                                Ext.MessageBox.confirm('Confirm', 'Are you sure you want to delete this file?', function(btn) {
                                    if (btn == 'no') {
                                        return false;
                                    } else if (btn == 'yes') {
                                        var msg = Ext.Msg.wait("Loading", "Deleting file...");

                                        Ext.Ajax.request({
                                            url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/delete_file',
                                            method: 'POST',
                                            params: Ext.apply({
                                                leaf: record.data.leaf,
                                                selected_nodes: Ext.JSON.encode(Ext.Array.map(selectedNodes, function(node, i) {
                                                    return node.data.id;
                                                }))
                                            }, self.extraPostData),
                                            success: function(response) {
                                                var responseObj = Ext.decode(response.responseText);
                                                msg.hide();
                                                if (responseObj.success) {
                                                    self.fireEvent('filedeleted', this, record);

                                                    record.parentNode.removeChild(record);
                                                } else {
                                                    Ext.Msg.alert("Error", responseObj.error);
                                                }
                                            },
                                            failure: function(response) {
                                                var responseObj = Ext.decode(response.responseText);
                                                msg.hide();
                                                Ext.Msg.alert('Status', responseObj.msg);
                                            }
                                        });
                                    }
                                });
                            }
                        }
                    });
                }

                //add additional menu items if they are passed in the config
                //check to see where the should show, folders, leafs, or all
                if (!Ext.isEmpty(self.initialConfig['additionalContextMenuItems'])) {
                    Ext.each(self.initialConfig['additionalContextMenuItems'], function(item) {
                        if (item.nodeType == 'folder' && !record.data['leaf']) {
                            menuItems.push(item);
                        } else if (item.nodeType == 'leaf' && record.data['leaf']) {
                            menuItems.push(item);
                        } else if (Compass.ErpApp.Utility.isBlank(item.nodeType)) {
                            menuItems.push(item);
                        }
                    });
                }

                //if this is not a leaf allow reload
                if (!record.data['leaf']) {
                    /*reload folder menu item*/
                    menuItems.push({
                        text: 'Reload',
                        iconCls: 'icon-recycle',
                        listeners: {
                            scope: this,
                            'click': function() {
                                if (!self.fireEvent('allowreload', this)) {
                                    currentUser.showInvalidAccess();
                                    return false;
                                }

                                // prevent double reload
                                if (!store.isLoading()) {
                                    // bugfix (clearOnLoad)
                                    while (delNode = self.selectedNode.childNodes[0]) {
                                        self.selectedNode.removeChild(delNode);
                                    }

                                    store.load({
                                        node: self.selectedNode,
                                        params: self.extraPostData,
                                        callback: function() {
                                            view.refresh();
                                        }
                                    });
                                }
                            }
                        }
                    });

                    /*upload menu item*/
                    menuItems.push({
                        text: 'Upload',
                        iconCls: 'icon-upload',
                        listeners: {
                            scope: self,
                            'click': function() {
                                if (!self.fireEvent('allowupload', this)) {
                                    currentUser.showInvalidAccess();
                                    return false;
                                }

                                var uploadWindow = new Compass.ErpApp.Shared.UploadWindow({
                                    standardUploadUrl: this.initialConfig['standardUploadUrl'],
                                    extraPostData: Ext.apply({
                                        directory: record.data.id
                                    }, self.extraPostData),
                                    listeners: {
                                        'fileuploaded': function(uploadWindow, response) {
                                            if (!record.isExpanded() && !record.isLoaded()) {
                                                record.expand();
                                            } else {
                                                if (response.success) {
                                                    record.appendChild(response.node);

                                                    if (!record.isExpanded()) {
                                                        record.expand();
                                                    }
                                                }
                                            }

                                            self.fireEvent('fileuploaded', this, record, response);
                                        }
                                    }
                                });
                                uploadWindow.show();
                            }
                        }
                    });

                    /*new file*/
                    if (self.initialConfig.showNewFileMenuItem !== false) {
                        menuItems.push({
                            text: 'New File',
                            iconCls: 'icon-document',
                            listeners: {
                                scope: self,
                                'click': function() {
                                    if (!self.fireEvent('allownewfile', this)) {
                                        currentUser.showInvalidAccess();
                                        return false;
                                    }
                                    Ext.MessageBox.prompt('New File', 'Please enter new file name:', function(btn, text) {
                                        if (btn == 'ok') {
                                            var msg = Ext.Msg.wait("Processing", "Creating new file...");

                                            Ext.Ajax.request({
                                                url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/create_file',
                                                method: 'POST',
                                                params: Ext.apply({
                                                    path: record.data.id,
                                                    name: text
                                                }, self.extraPostData),
                                                success: function(response) {
                                                    msg.hide();
                                                    if (!record.isExpanded() && !record.isLoaded()) {
                                                        record.expand();
                                                    } else {
                                                        var responseObj = Ext.decode(response.responseText);
                                                        if (responseObj.success) {
                                                            record.appendChild(responseObj.node);

                                                            if (!record.isExpanded()) {
                                                                record.expand();
                                                            }
                                                        }
                                                    }
                                                },
                                                failure: function() {
                                                    Ext.Msg.alert('Status', 'Error creating file.');
                                                    msg.hide();
                                                }
                                            });
                                        }
                                    });
                                }
                            }
                        });
                    }

                    /*new folder menu item*/
                    if (self.initialConfig.showNewFolderMenuItem !== false) {
                        menuItems.push({
                            text: 'New Folder',
                            iconCls: 'icon-content',
                            listeners: {
                                scope: this,
                                'click': function() {
                                    if (!self.fireEvent('allownewfolder', this)) {
                                        currentUser.showInvalidAccess();
                                        return false;
                                    }
                                    Ext.MessageBox.prompt('New Folder', 'Please enter new folder name:', function(btn, text) {
                                        if (btn == 'ok') {
                                            var msg = Ext.Msg.wait("Processing", "Creating new folder...");

                                            Ext.Ajax.request({
                                                url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/create_folder',
                                                method: 'POST',
                                                params: Ext.apply({
                                                    path: record.data.id,
                                                    name: text
                                                }, self.extraPostData),
                                                success: function(response) {
                                                    msg.hide();

                                                    if (!record.isExpanded() && !record.isLoaded()) {
                                                        record.expand();
                                                    } else {
                                                        var responseObj = Ext.decode(response.responseText);
                                                        if (responseObj.success) {
                                                            record.appendChild(responseObj.node);

                                                            if (!record.isExpanded()) {
                                                                record.expand();
                                                            }
                                                        }
                                                    }
                                                },
                                                failure: function() {
                                                    Ext.Msg.alert('Status', 'Error creating folder.');
                                                    msg.hide();
                                                }
                                            });
                                        }
                                    });
                                }
                            }
                        });
                    }
                } else {
                    //check if we are allowing to view contents
                    if (self.initialConfig['addViewContentsToContextMenu']) {
                        menuItems.push({
                            text: 'View Contents',
                            iconCls: 'icon-document',
                            listeners: {
                                'click': function() {
                                    if (!self.fireEvent('allowviewcontents', this)) {
                                        currentUser.showInvalidAccess();
                                        return false;
                                    }

                                    var fileType = record.data.id.split('.').pop();

                                    if (Ext.Array.indexOf(['png', 'gif', 'jpg', 'jpeg', 'ico', 'bmp', 'tif', 'tiff'], fileType.toLowerCase()) > -1) {
                                        self.fireEvent('showImage', this, record);
                                    } else {
                                        var msg = Ext.Msg.wait("Loading", "Retrieving contents...");
                                        Ext.Ajax.request({
                                            url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/get_contents',
                                            method: 'POST',
                                            params: {
                                                node: record.data.id
                                            },
                                            success: function(response) {
                                                msg.hide();
                                                self.fireEvent('contentLoaded', this, record, response.responseText);
                                            },
                                            failure: function() {
                                                Ext.Msg.alert('Status', 'Error loading contents');
                                                msg.hide();
                                            }
                                        });
                                    }
                                }
                            }
                        });
                    }

                    //if(this.initialConfig['allowDownload']){
                    menuItems.push({
                        text: 'Download File',
                        iconCls: 'icon-document',
                        listeners: {
                            'click': function() {
                                if (!self.fireEvent('allowdownload', this)) {
                                    currentUser.showInvalidAccess();
                                    return false;
                                }
                                if (self.fireEvent('downloadfile', this, record)) {
                                    window.open((self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + "/download_file/?path=" + record.data.id, 'mywindow', 'width=400,height=200');
                                }
                            }
                        }
                    }, {
                        text: 'Replace',
                        iconCls: 'icon-document',
                        listeners: {
                            'click': function() {
                                Ext.create("Ext.window.Window", {
                                    modal: true,
                                    title: 'Replace File',
                                    buttonAlign: 'center',
                                    items: {
                                        xtype: 'form',
                                        timeout: 300,
                                        frame: false,
                                        bodyStyle: 'padding:5px 5px 0',
                                        fileUpload: true,
                                        url: (self.initialConfig['controllerPath'] || '/erp_app/desktop/file_manager/base') + '/replace_file',
                                        items: [{
                                            xtype: 'fileuploadfield',
                                            width: '350px',
                                            fieldLabel: 'Replace File',
                                            buttonText: 'Upload',
                                            buttonOnly: false,
                                            allowBlank: false,
                                            name: 'replace_file_data'
                                        }]
                                    },
                                    buttons: [{
                                        text: 'Submit',
                                        listeners: {
                                            'click': function(button) {
                                                var _window = this.up('window'),
                                                    form = _window.query('form')[0].getForm();

                                                if (form.isValid()) {
                                                    form.submit({
                                                        timeout: 300000,
                                                        waitMsg: 'Replacing File...',
                                                        params: Ext.apply({
                                                            node: record.data.id
                                                        }, self.extraPostData),
                                                        success: function(form, action) {
                                                            _window.close();

                                                            if (action.result.success) {
                                                                record.set('text', action.result.name);
                                                                record.set('id', action.result.path);
                                                                record.commit();

                                                                self.fireEvent('filereplaced', this, record, action.result);

                                                            } else {
                                                                Ext.Msg.alert("Error", "Error replacing file");
                                                            }
                                                        },
                                                        failure: function(form, action) {
                                                            Ext.Msg.alert("Error", "Error replacing file");
                                                        }
                                                    });
                                                } else {
                                                    Ext.Msg.alert("Warning", "Please select a file to replace");
                                                }
                                            }
                                        }
                                    }, {
                                        text: 'Close',
                                        handler: function(btn) {
                                            btn.up('window').close();
                                        }
                                    }]
                                }).show();
                            }
                        }
                    });
                }

                var contextMenu = new Ext.menu.Menu({
                    items: menuItems
                });
                window.file_manager_context_menu_node = record;
                contextMenu.showAt(e.xy);
            }
        };

        var i;
        for (i in config.listeners)
            defaultListeners[i] = config.listeners[i];

        config['listeners'] = defaultListeners;

        config = Ext.apply({
            clearOnLoad: false,
            multiSelect: true,
            store: store,
            animate: false,
            containerScroll: true,
            autoDestroy: true,
            split: true,
            autoScroll: true,
            //margins: '5 0 5 5',
            viewConfig: {
                loadMask: true,
                plugins: {
                    ptype: 'treeviewdragdrop'
                },
                listeners: {
                    'beforedrop': function(node, data, overModel, dropPosition, dropHandlers, eOpts) {
                        // HACK: in ExtJS 4.2.1 self.getSelectionModel().getSelection(); returns an empty array in itemmove listener so we set a temp variable self.selectedNodes here for use by itemmove
                        self.selectedNodes = self.getSelectionModel().getSelection();
                    }
                }
            }
        }, config);

        this.callParent([config]);
    }
});
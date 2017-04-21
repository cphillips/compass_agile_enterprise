Ext.define("Compass.ErpApp.Desktop.Applications.Knitkit.ImageAssetsPanel", {
    extend: "Ext.tab.Panel",
    alias: 'widget.knitkit_ImageAssetsPanel',
    cls: 'image-assets-panel',

    constructor: function(config) {
        this.websiteId = null;
        var self = this;
        self.module = config.module;

        this.sharedImageAssetsDataView = Ext.create("Compass.ErpApp.Desktop.Applications.Knitkit.ImageAssetsDataView", {
            url: '/knitkit/erp_app/desktop/image_assets/shared/get_images',
            uploadUrl: '/knitkit/erp_app/desktop/image_assets/shared/upload_file',
            module: config.module,
            listeners: {
                imageuploaded: function(comp, node) {
                    var record = self.sharedImageAssetsTreePanel.selectedDirectoryNode;

                    if (!record.isExpanded() && !record.isLoaded()) {
                        record.expand();
                    } else {
                        record.appendChild(node);

                        if (!record.isExpanded()) {
                            record.expand();
                        }
                    }
                }
            }
        });
        this.websiteImageAssetsDataView = Ext.create("Compass.ErpApp.Desktop.Applications.Knitkit.ImageAssetsDataView", {
            module: config.module,
            url: '/knitkit/erp_app/desktop/image_assets/website/get_images',
            uploadUrl: '/knitkit/erp_app/desktop/image_assets/website/upload_file',
            listeners: {
                imageuploaded: function(comp, node) {
                    var record = self.websiteImageAssetsTreePanel.selectedDirectoryNode;

                    if (!record.isExpanded() && !record.isLoaded()) {
                        record.expand();
                    } else {
                        record.appendChild(node);

                        if (!record.isExpanded()) {
                            record.expand();
                        }
                    }
                }
            }
        });

        this.sharedImageAssetsTreePanel = Ext.create("Compass.ErpApp.Shared.FileManagerTree", {
            region: 'north',
            rootText: 'Shared Images',
            collapsible: false,
            allowDownload: false,
            addViewContentsToContextMenu: false,
            showNewFileMenuItem: false,
            rootVisible: true,
            multiSelect: true,
            controllerPath: '/knitkit/erp_app/desktop/image_assets/shared',
            standardUploadUrl: '/knitkit/erp_app/desktop/image_assets/shared/upload_file',
            url: '/knitkit/erp_app/desktop/image_assets/shared/expand_directory',
            containerScroll: true,
            height: 200,
            additionalContextMenuItems: [{
                nodeType: 'leaf',
                text: 'Insert image at cursor',
                iconCls: 'icon-add',
                listeners: {
                    scope: self,
                    'click': function() {
                        var node = this.sharedImageAssetsTreePanel.selectedNode;

                        var imgTagHtml = '<img';
                        if (!Ext.isEmpty(node.data.width) && !Ext.isEmpty(node.data.height)) {
                            imgTagHtml += (' width="' + node.data.width + '" height="' + node.data.height + '"');
                        }
                        imgTagHtml += ' alt="' + node.get('name') + '" src="' + node.get('url') + '" >';
                        self.module.centerRegion.insertHtmlIntoActiveCkEditorOrCodemirror(imgTagHtml);
                    }
                }
            }],
            listeners: {
                'allowdelete': function() {
                    return currentUser.hasCapability('delete', 'GlobalImageAsset');
                },
                'allowupload': function() {
                    return currentUser.hasCapability('upload', 'GlobalImageAsset');
                },
                'itemclick': function(view, record, item, index, e) {
                    e.stopEvent();
                    if (!record.data["leaf"]) {
                        this.selectedDirectoryNode = record;
                        self.sharedImageAssetsDataView.setPath(record.getPath('text'));
                        self.sharedImageAssetsDataView.directory = record.data.id;
                        var store = self.sharedImageAssetsDataView.getStore();
                        store.load({
                            params: {
                                directory: record.data.id
                            }
                        });
                    } else {
                        return false;
                    }
                },
                'filedeleted': function(fileTreePanel, node) {
                    self.sharedImageAssetsDataView.getStore().load({
                        params: {
                            directory: node.parentNode.data.id
                        }
                    });
                },
                'fileuploaded': function(fileTreePanel, node) {
                    self.sharedImageAssetsDataView.getStore().load({
                        params: {
                            directory: node.data.id
                        }
                    });
                },
                'downloadfile': function(fileTreePanel, node) {
                    window.open("/download/" + node.data.text + "?path=" + node.data.downloadPath + '&disposition=attachment', 'mywindow', 'width=400,height=200');
                    return false;
                },
                'filereplaced': function(fileTreePanel, node) {
                    self.sharedImageAssetsDataView.getStore().load({
                        params: {
                            directory: node.data.id
                        }
                    });
                }
            }
        });

        this.websiteImageAssetsTreePanel = Ext.create("Compass.ErpApp.Shared.FileManagerTree", {
            autoLoadRoot: false,
            region: 'north',
            rootText: 'Images',
            collapsible: false,
            allowDownload: false,
            addViewContentsToContextMenu: false,
            showNewFileMenuItem: false,
            rootVisible: true,
            multiSelect: true,
            controllerPath: '/knitkit/erp_app/desktop/image_assets/website',
            standardUploadUrl: '/knitkit/erp_app/desktop/image_assets/website/upload_file',
            url: '/knitkit/erp_app/desktop/image_assets/website/expand_directory',
            containerScroll: true,
            height: 200,
            additionalContextMenuItems: [{
                nodeType: 'leaf',
                text: 'Insert image at cursor',
                iconCls: 'icon-add',
                listeners: {
                    scope: self,
                    'click': function() {
                        var node = this.websiteImageAssetsTreePanel.selectedNode;

                        var imgTagHtml = '<img';
                        if (!Ext.isEmpty(node.data.width) && !Ext.isEmpty(node.data.height)) {
                            imgTagHtml += (' width="' + node.data.width + '" height="' + node.data.height + '"');
                        }
                        imgTagHtml += ' alt="' + node.get('name') + '" src="' + node.get('url') + '" >';
                        self.module.centerRegion.insertHtmlIntoActiveCkEditorOrCodemirror(imgTagHtml);
                    }
                }
            }],
            listeners: {
                'load': function(store, node, records) {
                    store.getRootNode().data.text = self.websiteName;
                    self.websiteImageAssetsTreePanel.view.refresh();
                },
                'itemclick': function(view, record, item, index, e) {
                    if (self.websiteId !== null) {
                        e.stopEvent();
                        if (!record.data["leaf"]) {
                            this.selectedDirectoryNode = record;
                            self.websiteImageAssetsDataView.setPath(record.getPath('text'));
                            self.websiteImageAssetsDataView.directory = record.data.id;
                            self.websiteImageAssetsDataView.websiteId = self.websiteId;
                            var store = self.websiteImageAssetsDataView.getStore();
                            store.load({
                                params: {
                                    directory: record.data.id,
                                    website_id: self.websiteId
                                }
                            });
                        } else {
                            return false;
                        }
                    }
                },
                'filedeleted': function(fileTreePanel, node) {
                    self.websiteImageAssetsDataView.getStore().load({
                        params: {
                            directory: node.parentNode.isRoot() ? 'root_node' : node.parentNode.data.id,
                            website_id: self.websiteId
                        }
                    });
                },
                'fileuploaded': function(fileTreePanel, node) {
                    self.websiteImageAssetsDataView.getStore().load({
                        params: {
                            directory: node.parentNode.isRoot() ? 'root_node' : node.parentNode.data.id,
                            website_id: self.websiteId
                        }
                    });
                },
                'downloadfile': function(fileTreePanel, node) {
                    window.open("/download/" + node.data.text + "?path=" + node.data.downloadPath + '&disposition=attachment', 'mywindow', 'width=400,height=200');
                    return false;
                },
                'filereplaced': function(fileTreePanel, node) {
                    self.websiteImageAssetsDataView.getStore().load({
                        params: {
                            directory: node.parentNode.isRoot() ? 'root_node' : node.parentNode.data.id,
                            website_id: self.websiteId
                        }
                    });
                }
            }
        });

        var sharedImagesPanel = Ext.create('Ext.panel.Panel', {
            cls: 'image-assets',
            region: 'center',
            margins: '0 0 0 0',
            layout: 'fit',
            items: this.sharedImageAssetsDataView
        });

        var websiteImagesPanel = Ext.create('Ext.panel.Panel', {
            cls: 'image-assets',
            region: 'center',
            margins: '0 0 0 0',
            layout: 'fit',
            items: this.websiteImageAssetsDataView
        });

        var sharedImagesLayout = Ext.create('Ext.panel.Panel', {
            layout: 'border',
            title: 'Shared',
            items: [this.sharedImageAssetsTreePanel, sharedImagesPanel]
        });

        var websiteImagesLayout = Ext.create('Ext.panel.Panel', {
            autoRender: true,
            layout: 'border',
            title: 'Website',
            items: [this.websiteImageAssetsTreePanel, websiteImagesPanel]
        });

        this.selectWebsite = function(website) {
            this.websiteId = website.id;
            this.websiteName = website.name;
            this.reloadWebsiteImageAssetsTreePanel(website.id);
        };

        this.clearWebsite = function() {
            this.websiteId = null;
            this.websiteName = null;

            this.websiteImageAssetsTreePanel.extraPostData = {
                website_id: null
            };
            this.websiteImageAssetsTreePanel.getStore().setProxy({
                type: 'ajax',
                url: '/knitkit/erp_app/desktop/file_assets/website/expand_directory',
                extraParams: {
                    website_id: null
                }
            });

            this.websiteImageAssetsTreePanel.getRootNode().removeAll(true);
        };

        this.reloadWebsiteImageAssetsTreePanel = function(websiteId) {
            this.websiteImageAssetsTreePanel.extraPostData = {
                website_id: websiteId
            };
            this.websiteImageAssetsTreePanel.getStore().setProxy({
                type: 'ajax',
                url: '/knitkit/erp_app/desktop/image_assets/website/expand_directory',
                extraParams: {
                    website_id: websiteId
                }
            });

            if (websiteId) {
                var rootNode = this.websiteImageAssetsTreePanel.getRootNode();

                while (delNode = rootNode.childNodes[0]) {
                    rootNode.removeChild(delNode);
                }
                rootNode.expand();

                if (!this.websiteImageAssetsTreePanel.getStore().isLoading()) {
                    this.websiteImageAssetsTreePanel.getStore().load();
                    self.websiteImageAssetsDataView.directory = 'root_node';
                    self.websiteImageAssetsDataView.websiteId = websiteId;
                    self.websiteImageAssetsDataView.getStore().load({
                        params: {
                            directory: 'root_node',
                            website_id: websiteId
                        },
                        callback: function() {
                            self.websiteImageAssetsTreePanel.selectedDirectoryNode = rootNode;
                            self.websiteImageAssetsDataView.setPath('/' + rootNode.data.text);
                        }
                    });
                }
            }
        };

        var items = [];

        if (currentUser.hasCapability('view', 'SiteImageAsset')) {
            items.push(websiteImagesLayout);
        }

        if (currentUser.hasCapability('view', 'GlobalImageAsset')) {
            items.push(sharedImagesLayout);
        }

        config = Ext.apply({
            deferredRender: false,
            layout: 'fit',
            title: 'Images',
            items: items,
            activeTab: 1,
            listeners: {
                afterrender: function(panel) {
                    // workaround for extJS rendering bug. set activetab 1 above and 0 afterrender
                    panel.setActiveTab(0);

                    // load shared assets
                    var rootNode = panel.sharedImageAssetsTreePanel.getRootNode();
                    panel.sharedImageAssetsTreePanel.selectedDirectoryNode = rootNode;
                    panel.sharedImageAssetsDataView.setPath(rootNode.getPath('text'));
                    panel.sharedImageAssetsDataView.directory = rootNode.data.id;
                    panel.sharedImageAssetsDataView.getStore().load({
                        params: {
                            directory: rootNode.data.id
                        }
                    });
                }
            }
        }, config);

        this.callParent([config]);

    }
});
require 'yaml'
require 'fileutils'

class Theme < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  THEME_STRUCTURE = ['stylesheets', 'javascripts', 'images', 'templates', 'fonts']

  @base_layouts_views_path = "#{Knitkit::Engine.root.to_s}/app/views"
  @knitkit_website_stylesheets_path = "#{Knitkit::Engine.root.to_s}/app/assets/stylesheets/knitkit"
  @knitkit_website_javascripts_path = "#{Knitkit::Engine.root.to_s}/app/assets/javascripts/knitkit"
  @knitkit_website_images_path = "#{Knitkit::Engine.root.to_s}/public/images/knitkit"
  @knitkit_website_fonts_path = "#{Knitkit::Engine.root.to_s}/app/assets/fonts/knitkit"

  protected_with_capabilities
  has_file_assets


  validates :name, :presence => {:message => 'Name cannot be blank'}
  validates_uniqueness_of :theme_id, :scope => :website_id, :case_sensitive => false

  belongs_to :website

  extend FriendlyId
  friendly_id :name, :use => [:slugged, :scoped], :slug_column => :theme_id, :scope => [:website_id]

  def import_download_item_file(file)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)

    theme_root = Theme.find_theme_root_from_file(file)

    Zip::ZipFile.open(file) do |zip|
      zip.each do |entry|
        if entry.name == 'about.yml'
          data = ''
          entry.get_input_stream { |io| data = io.read }
          data = StringIO.new(data) if data.present?
          about = YAML.load(data)
          self.author = about['author'] if about['author']
          self.version = about['version'] if about['version']
          self.homepage = about['homepage'] if about['homepage']
          self.summary = about['summary'] if about['summary']
        else
          name = entry.name.sub(/__MACOSX\//, '')
          name = Theme.strip_path(name, theme_root)
          data = ''
          entry.get_input_stream { |io| data = io.read }
          data = StringIO.new(data) if data.present?
          theme_file = self.files.where("name = ? and directory = ?", File.basename(name), File.join(self.url, File.dirname(name))).first
          unless theme_file.nil?
            theme_file.data = data
            theme_file.save
          else
            self.add_file(data, File.join(file_support.root, self.url, name)) rescue next
          end
        end
      end
    end
    activate!
  end

  def should_generate_new_friendly_id?
    new_record?
  end

  validates :name, :presence => {:message => 'Name cannot be blank'}
  validates_uniqueness_of :theme_id, :scope => :website_id, :case_sensitive => false

  before_destroy :delete_theme_files!

  class << self
    attr_accessor :base_layouts_views_path, :knitkit_website_stylesheets_path,
                  :knitkit_website_images_path, :knitkit_website_javascripts_path,
                  :knitkit_website_fonts_path

    def import_download_item(tempfile, website)
      name_and_id = tempfile.gsub(/(^.*(\\|\/))|(\.zip$)/, '')
      theme_name = name_and_id.split('[').first
      theme_id = name_and_id.split('[').last.gsub(']', '')
      Theme.create(:name => theme_name.sub(/-theme/, ''), :theme_id => theme_id, :website_id => website.id).tap do |theme|
        theme.import_download_item_file(tempfile)
      end
    end

    def find_theme_root_from_file(file)
      theme_root = ''
      Zip::ZipFile.open(file) do |zip|
        zip.each do |entry|
          entry.name.sub!(/__MACOSX\//, '')
          if theme_root == root_in_path(entry.name)
            break
          end
        end
      end
      theme_root
    end

    def root_dir
      @@root_dir ||= "#{Rails.root}/public"
    end

    def base_dir(website)
      "#{root_dir}/sites/#{website.iid}/themes"
    end

    def import(file_path, website, auto_activate=false)
      # if the path to the file is passed just use it else get the path from
      # the File object that was passed
      if file_path.is_a?(String)
        name_and_id = File.basename(file_path).to_s.gsub(/(^.*(\\|\/))|(\.zip$)/, '')
      else
        name_and_id = File.basename(file_path.original_filename).to_s.gsub(/(^.*(\\|\/))|(\.zip$)/, '')

        if file_path.path
          file_path = file_path.path
        else
          file = ActionController::UploadedTempfile.new("uploaded-website").tap do |f|
            f.puts file_path.read
            f.original_filename = file_path.original_filename
            f.read # no idea why we need this here, otherwise the zip can't be opened
          end
          file_path = file.path
        end
      end

      theme_name = name_and_id.split('[').first
      theme_id = name_and_id.split('[').last.gsub(']', '')
      return false unless valid_theme?(file_path)
      Theme.create(:name => theme_name, :theme_id => theme_id, :website => website).tap do |theme|
        theme.import(file_path, auto_activate)
      end
    end

    def make_tmp_dir
      Pathname.new(Rails.root.to_s + "/tmp/themes/tmp_#{Time.now.to_i.to_s}/").tap do |dir|
        FileUtils.mkdir_p(dir) unless dir.exist?
      end
    end

    def valid_theme?(file_path)
      valid = false
      Zip::ZipFile.open(file_path) do |zip|
        zip.sort.each do |entry|
          entry.name.split('/').each do |file|
            valid = true if THEME_STRUCTURE.include?(file)
          end
        end
      end
      valid
    end

    def find_theme_root(file_path)
      theme_root = ''
      Zip::ZipFile.open(file_path) do |zip|
        zip.each do |entry|
          entry.name.sub!(/__MACOSX\//, '')
          if theme_root = root_in_path(entry.name)
            break
          end
        end
      end
      theme_root
    end

    def root_in_path(path)
      root_found = false
      theme_root = ''
      path.split('/').each do |piece|
        if piece == 'about.yml' || THEME_STRUCTURE.include?(piece)
          root_found = true
        else
          theme_root += piece + '/' if !piece.match('\.') && !root_found
        end
      end
      root_found ? theme_root : false
    end

    def strip_path(file_name, path)
      file_name.sub(path, '')
    end
  end

  validates :name, :presence => {:message => 'Name cannot be blank'}
  validates_uniqueness_of :theme_id, :scope => :website_id, :case_sensitive => false

  before_destroy :delete_theme_files!

  def path
    "#{self.class.base_dir(website)}/#{theme_id}"
  end

  def url
    "/public/sites/#{website.iid}/themes/#{theme_id}"
  end

  def activate!
    update_attributes! :active => true
  end

  def deactivate!
    update_attributes! :active => false
  end

  def themed_widgets
    Rails.application.config.erp_app.widgets.select do |widget_hash|
      !(self.files.where("directory like '#{File.join(self.url, 'widgets', widget_hash[:name])}%'").all.empty?)
    end.collect { |item| item[:name] }
  end

  def non_themed_widgets
    already_themed_widgets = self.themed_widgets
    Rails.application.config.erp_app.widgets.select do |widget_hash|
      !already_themed_widgets.include?(widget_hash[:name])
    end.collect { |item| item[:name] }
  end

  def create_layouts_for_widget(widget)
    widget_hash = Rails.application.config.erp_app.widgets.find { |item| item[:name] == widget }
    widget_hash[:view_files].each do |view_file|
      save_theme_file(view_file[:path], :widgets, {:path_to_replace => view_file[:path].split('/views')[0], :widget_name => widget})
    end
  end

  def about
    %w(name author version homepage summary).inject({}) do |result, key|
      result[key] = send(key)
      result
    end
  end

  def import(file_path, auto_activate=false)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
    theme_root = Theme.find_theme_root(file_path)

    Zip::ZipFile.open(file_path) do |zip|
      zip.each do |entry|
        if entry.name == 'about.yml'
          data = ''
          entry.get_input_stream { |io| data = io.read }
          data = StringIO.new(data) if data.present?
          about = YAML.load(data)
          self.author = about['author'] if about['author']
          self.version = about['version'] if about['version']
          self.homepage = about['homepage'] if about['homepage']
          self.summary = about['summary'] if about['summary']
        else
          name = entry.name.sub(/__MACOSX\//, '')
          name = Theme.strip_path(name, theme_root)
          data = ''
          entry.get_input_stream { |io| data = io.read }
          data = StringIO.new(data) if data.present?
          theme_file = self.files.where("name = ? and directory = ?", File.basename(name), File.join(self.url, File.dirname(name))).first
          unless theme_file.nil?
            theme_file.data = data
            theme_file.save
          else
            self.add_file(data, File.join(file_support.root, self.url, name))
          end
        end
      end
    end

    if auto_activate
      self.activate!
    end

    self
  end

  def export
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
    tmp_dir = Theme.make_tmp_dir
    (tmp_dir + "#{name}[#{theme_id}].zip").tap do |file_name|
      file_name.unlink if file_name.exist?
      Zip::ZipFile.open(file_name.to_s, Zip::ZipFile::CREATE) do |zip|
        files.each { |file|
          contents = file_support.get_contents(File.join(file_support.root, file.directory, file.name))
          relative_path = file.directory.sub("#{url}", '')
          path = FileUtils.mkdir_p(File.join(tmp_dir, relative_path))
          full_path = File.join(path, file.name)
          File.open(full_path, 'wb+') { |f| f.puts(contents) }
          zip.add(File.join(relative_path[1..relative_path.length], file.name), full_path) if ::File.exists?(full_path)
        }
        ::File.open(tmp_dir + 'about.yml', 'wb+') { |f| f.puts(about.to_yaml) }
        zip.add('about.yml', tmp_dir + 'about.yml')
      end
    end
  end

  def has_template?(directory, name)
    self.templates.find { |item| item.directory == File.join(path, directory).gsub(Rails.root.to_s, '') and item.name == name }
  end

  def delete_theme_files!
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    file_support.delete_file(File.join(file_support.root, self.url), :force => true)
  end

  def create_theme_files!
    file_support = ErpTechSvcs::FileSupport::Base.new
    create_theme_files_for_directory_node(file_support.build_tree(Theme.base_layouts_views_path, :preload => true), :templates, :path_to_replace => Theme.base_layouts_views_path)
    create_theme_files_for_directory_node(file_support.build_tree(Theme.knitkit_website_stylesheets_path, :preload => true), :stylesheets, :path_to_replace => Theme.knitkit_website_stylesheets_path)
    create_theme_files_for_directory_node(file_support.build_tree(Theme.knitkit_website_javascripts_path, :preload => true), :javascripts, :path_to_replace => Theme.knitkit_website_javascripts_path)
    create_theme_files_for_directory_node(file_support.build_tree(Theme.knitkit_website_images_path, :preload => true), :images, :path_to_replace => Theme.knitkit_website_images_path)
    create_theme_files_for_directory_node(file_support.build_tree(Theme.knitkit_website_fonts_path, :preload => true), :fonts, :path_to_replace => Theme.knitkit_website_fonts_path)
  end

  private

  def create_theme_files_for_directory_node(node, type, options={})
    if node
      node[:children].each do |child_node|
        child_node[:leaf] ? save_theme_file(child_node[:id], type, options) : create_theme_files_for_directory_node(child_node, type, options)
      end
    end
  end

  def save_theme_file(path, type, options)
    ignored_css = [
        'bootstrap.min.css',
        'inline_editing.css',
    ]

    ignored_js = [
        'additional-methods.min',
        'bootstrap.min.js',
        'confirm-bootstrap.js',
        'inline_editing.js',
        'jquery.maskedinput.min.js',
        'jquery.validate.min.js'
    ]

    ignored_files = (ignored_css | ignored_js).flatten

    unless ignored_files.any? { |w| path =~ /#{w}/ }
      contents = IO.read(path)
      contents.gsub!("<%= stylesheet_link_tag 'knitkit/custom' %>", "<%= theme_stylesheet_link_tag '#{self.theme_id}','custom.css' %>") unless path.scan('base.html.erb').empty?
      contents.gsub!("<%= javascript_include_tag 'knitkit/theme' %>", "<%= theme_javascript_include_tag '#{self.theme_id}','theme.js' %>") unless path.scan('base.html.erb').empty?

      path = case type
               when :widgets
                 path.gsub(options[:path_to_replace], "#{self.url}/widgets/#{options[:widget_name]}")
               else
                 path.gsub(options[:path_to_replace], "#{self.url}/#{type.to_s}")
             end

      self.add_file(contents, path)
    end

  end
end
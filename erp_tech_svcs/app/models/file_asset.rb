# create_table :file_assets do |t|
#   t.string :type
#   t.string :name
#   t.string :directory
#   t.string :data_file_name
#   t.string :data_content_type
#   t.integer :data_file_size
#   t.datetime :data_updated_at
#   t.text :scoped_by
#   t.string :width
#   t.string :height
#   t.string :description
#
#   t.timestamps
# end
# add_index :file_assets, :type
# add_index :file_assets, [:file_asset_holder_id, :file_asset_holder_type], :name => 'file_asset_holder_idx'
# add_index :file_assets, :name
# add_index :file_assets, :directory

require 'fileutils'

Paperclip.interpolates(:file_path) { |data, style|
  case ErpTechSvcs::Config.file_storage
  when :filesystem
    file_support = ErpTechSvcs::FileSupport::Base.new
    File.join(file_support.root, data.instance.directory, data.instance.name)
  when :s3
    File.join(data.instance.directory, data.instance.name)
  end
}

Paperclip.interpolates(:file_url) { |data, style|
  url = File.join(data.instance.directory, data.instance.name)
  case ErpTechSvcs::Config.file_storage
  when :filesystem
    #if public is at the front of this path and we are using file_system remove it
    dir_pieces = url.split('/')
    unless dir_pieces[1] == 'public'
      "/download/#{data.instance.name}?path=#{dir_pieces.delete_if { |name| name == data.instance.name }.join('/')}"
    else
      dir_pieces.delete_at(1) if dir_pieces[1] == 'public'
      dir_pieces.join('/')
    end
  when :s3
    url
  end
}

class FileAsset < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  tracks_created_by_updated_by

  if respond_to?(:class_attribute)
    class_attribute :file_type
    class_attribute :valid_extensions
    class_attribute :content_type
  else
    class_inheritable_accessor :file_type
    class_inheritable_accessor :content_type
    class_inheritable_writer :valid_extensions
  end

  # setup scoping
  add_scoped_by :scoped_by

  after_create :set_sti
  # must fire after paperclip's after_save :save_attached_files
  after_save :set_data_file_name

  before_validation(on: :create) do
    self.check_name_uniqueness
  end

  has_many :file_asset_holders, class_name: 'FileAssetHolder', foreign_key: 'file_asset_id', dependent: :destroy

  acts_as_taggable

  instantiates_with_sti

  protected_with_capabilities

  #paperclip
  has_attached_file :data,
    :storage => ErpTechSvcs::Config.file_storage,
    :s3_protocol => ErpTechSvcs::Config.s3_protocol,
    :s3_permissions => :public_read,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :path => ":file_path",
    :url => (ErpTechSvcs::Config.file_storage == :filesystem ? ":file_url" : (ErpTechSvcs::Config.s3_url || ":file_url")),
    :validations => {:extension => lambda { |data, file| validate_extension(data, file) }}

  before_post_process :set_content_type
  before_save :save_dimensions

  validates_attachment_presence :data
  validates_attachment_size :data, :less_than => ErpTechSvcs::Config.max_file_size_in_mb.megabytes

  validates :name, :presence => {:message => 'Name can not be blank'}
  validates_uniqueness_of :name, :scope => [:directory], :case_sensitive => false
  validates_each :directory, :name do |record, attr, value|
    record.errors.add attr, 'may not contain consequtive dots' if value =~ /\.\./
  end
  validates_format_of :name, :with => /^\w/

  class << self
    def adjust_image(data, size=nil)
      file_support = ErpTechSvcs::FileSupport::FileSystemManager.new
      name = "#{SecureRandom.uuid}.jpg"
      path = File.join(Rails.root, 'tmp', name)

      data = StringIO.new(data) if data.is_a?(String)
      File.open(path, 'wb+') { |f| f.write(data.read) }

      # resize
      if size
        Paperclip.run("convert", "#{path} -resize #{size}^ #{path}", :swallow_stderr => false)
      end

      # rotate
      Paperclip.run("convert", "#{path} -auto-orient #{path}", :swallow_stderr => false)

      #remove the file after we get the data
      data = file_support.get_contents(path)[0]
      FileUtils.rm(path)

      data
    end

    def acceptable?(name)
      valid_extensions.include?(File.extname(name))
    end

    def type_for(name)
      classes = all_subclasses.uniq
      classes.detect { |k| k.acceptable?(name) }.try(:name)
    end

    def type_by_extension(extension)
      klass = all_subclasses.detect { |k| k.valid_extensions.include?(extension) }
      klass = TextFile if klass.nil?
      klass
    end

    def validate_extension(data, file)
      if file.name && !file.class.valid_extensions.include?(File.extname(file.name))
        types = all_valid_extensions.map { |type| type.gsub(/^\./, '') }.join(', ')
        "#{file.name} is not a valid file type. Valid file types are #{types}."
      end
    end

    def valid_extensions
      read_inheritable_attribute(:valid_extensions) || []
    end

    def all_valid_extensions
      all_subclasses.map { |k| k.valid_extensions }.flatten.uniq
    end

    def split_path(path)
      directory, name = ::File.split(path)
      directory = nil if directory == '.'
      [directory, name]
    end

    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      statement = FileAsset unless statement

      if filters[:file_asset_holder_type].present? && filters[:file_asset_holder_id].present?
        statement = statement.joins(:file_asset_holders)
        .where(file_asset_holders: {
                 file_asset_holder_id: filters[:file_asset_holder_id],
                 file_asset_holder_type: filters[:file_asset_holder_type]
        })
      end

      if filters[:scopes]
        JSON.parse(filters[:scopes]).each do |scope|
          scope = Hash.symbolize_keys(scope)

          self.scoped_by(scope[:name], scope[:value])
        end
      end

      statement
    end

    # scope by dba organization
    #
    # @param dba_organization [Party] dba organization to scope by
    #
    # @return [ActiveRecord::Relation]
    def scope_by_dba_organization(dba_organization)
      scope_by_party(dba_organization, {role_types: [RoleType.iid('dba_org')]})
    end

    alias scope_by_dba_org scope_by_dba_organization

    # scope by party
    #
    # @param party [Integer | Party | Array] either a id of Party record, a Party record, an array of Party records
    # or an array of Party ids
    # @param options [Hash] options to apply to this scope
    # @option options [Array] :role_types role types to include in the scope
    #
    # @return [ActiveRecord::Relation]
    def scope_by_party(party, options={})
      table_alias = String.random

      if options[:role_types]
        joins("inner join entity_party_roles as #{table_alias} on #{table_alias}.entity_record_type = 'FileAsset'
                                     and #{table_alias}.entity_record_id = file_assets.id and
                                     #{table_alias}.role_type_id in (#{RoleType.find_child_role_types(options[:role_types]).collect(&:id).join(',')})
                                     and #{table_alias}.party_id in (#{Party.select('id').where(id: party).to_sql})")

      else
        joins("inner join entity_party_roles as #{table_alias} on #{table_alias}.entity_record_type = 'FileAsset'
                                     and #{table_alias}.entity_record_id = file_assets.id
                                     and #{table_alias}.party_id in (#{Party.select('id').where(id: party).to_sql})")
      end
    end
  end

  def initialize(attributes = {}, options={})
    attributes ||= {}

    base_path = attributes.delete(:base_path)
    @type, directory, name, data = attributes.values_at(:type, :directory, :name, :data)
    base_path ||= data.original_filename if data.respond_to?(:original_filename)

    directory, name = FileAsset.split_path(base_path) if base_path and name.blank?
    directory.gsub!(Rails.root.to_s, '') if directory

    @type ||= FileAsset.type_for(name) if name
    @type = "TextFile" if @type.nil?
    @name = name

    data = StringIO.new(data) if data.is_a?(String)

    super attributes.merge(:directory => directory, :name => name, :data => data)
  end

  def fully_qualified_url
    case ErpTechSvcs::Config.file_storage
    when :filesystem
      "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, data.url)}"
    when :s3
      data.url
    end
  end

  def check_name_uniqueness
    # check if name is already taken
    unless FileAsset.where('directory = ? and name = ?', self.directory, self.name).first.nil?
      # if it is keeping add incrementing by 1 until we have a good name
      counter = 0
      while true
        counter += 1

        # break after 25, we don't want in infinite loop
        break if counter == 25

        new_name = "#{basename}-#{counter}.#{extname}"

        if FileAsset.where('directory = ? and name = ?', self.directory, new_name).first.nil?
          self.name = new_name
          break
        end
      end
    end
  end

  def base64encoded
    Base64.encode64(get_contents.first())
  end

  def is_secured?
    self.protected_with_capability?('download')
  end

  def copy(path, name)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

    file_support.copy(self.path, path, name)
  end

  # compass file download url
  def url
    "/download/#{self.name}?path=#{self.directory}"
  end

  # returns full path to local image or url to s3 image
  def path
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

    if ErpTechSvcs::Config.file_storage == :s3
      file_path = File.join(self.directory, self.name).sub(%r{^/}, '')
      options = {}
      options[:expires] = ErpTechSvcs::Config.s3_url_expires_in_seconds if self.is_secured?
      file_support.bucket.objects[file_path].url_for(:read, options).to_s
    else
      File.join(Rails.root, self.directory, self.name)
    end
  end

  def save_dimensions
    if @type == 'Image'
      begin
        tempfile = data.queued_for_write[:original]
        unless tempfile.nil?
          geometry = Paperclip::Geometry.from_file(tempfile)
          w = geometry.width.to_i
          h = geometry.height.to_i
          update_attribute(:width, w) if width != w
          update_attribute(:height, h) if height != h
        end
      rescue => ex
        Rails.logger.error('Could not save width and height of image. Make sure Image Magick and the identify command are accessible')
      end
    end
    #return true
  end

  def basename
    name.gsub(/\.#{extname}$/, "")
  end

  def trim_name(size)
    if self.name.length < size
      self.name
    else
      self.name[0..size]
    end
  end

  def extname
    File.extname(name).gsub(/^\.+/, '')
  end

  def set_sti
    update_attribute :type, @type
  end

  def replace!(old_path, new_path, contents)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

    file_support.replace_file(File.join(file_support.root, old_path),
                              File.join(file_support.root, new_path),
                              contents)

    new_name = ::File.basename(new_path)
    new_dir = ::File.dirname(new_path)

    self.name = new_name
    self.directory = new_dir
    self.save!

    set_data_file_name
  end

  def set_content_type
    unless @type.nil?
      klass = @type.constantize
      content_type = klass == Image ? "image/#{File.extname(@name).gsub(/^\.+/, '')}" : klass.content_type
      self.data.instance_write(:content_type, content_type)
    end
  end

  def set_data_file_name
    update_attribute :data_file_name, name if data_file_name != name
  end

  def get_contents
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    file_support.get_contents(File.join(file_support.root, self.directory, self.data_file_name))
  end

  def move(new_parent_path)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

    if ErpTechSvcs::Config.file_storage == :filesystem and !self.directory.include?(Rails.root.to_s)
      old_path = File.join(Rails.root, self.directory, self.name)
    else
      old_path = File.join(self.directory, self.name)
    end

    result, message = file_support.save_move(old_path, new_parent_path)
    if result
      dir = new_parent_path.gsub(Regexp.new(Rails.root.to_s), '') # strip rails root from new_parent_path, we want relative path
      dir = '/' + dir unless dir.match(%r{^/})
      self.directory = dir
      self.save
    end

    return result, message
  end

  def to_s
    self.description
  end

  def to_data_hash
    data = to_hash(only: [:id, :directory, :width, :height, :name, :description])

    data[:url] = self.data.url
    data[:fully_qualified_url] = self.fully_qualified_url
    data[:tags] = self.tag_list.join(',')
    data[:thumbnail_src] = self.thumbnail_src

    data
  end

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, 'assets/default_file.png')}"
  end

end

class Image < FileAsset
  self.file_type = :image
  self.valid_extensions = %w(.jpg .JPG .jpeg .JPEG .gif .GIF .png .PNG .ico .ICO .bmp .BMP .tif .tiff .TIF .TIFF)

  def thumbnail_src
    thumbnail_image = FileAsset.where("data_file_name = ? and directory like '%thumbnail%' and id = ?", self.name, self.id).first

    if thumbnail_image
      thumbnail_image.fully_qualified_url
    else
      self.fully_qualified_url
    end
  end
end

class TextFile < FileAsset
  self.file_type = :textfile
  self.content_type = 'text/plain'
  self.valid_extensions = %w(.txt .TXT .text)

  def data=(data)
    data = StringIO.new(data) if data.is_a?(String)
    super
  end

  def text
    @text ||= ::File.read(path) rescue ''
  end

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, 'assets/default_file.png')}"
  end
end

class Javascript < TextFile
  self.file_type = :javascript
  self.content_type = 'text/javascript'
  self.valid_extensions = %w(.js .JS)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/javascript_file.png')}"
  end
end

class Stylesheet < TextFile
  self.file_type = :stylesheet
  self.content_type = 'text/css'
  self.valid_extensions = %w(.css .CSS)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/css_file.png')}"
  end
end

class Template < TextFile
  self.file_type = :template
  self.content_type = 'text/plain'
  self.valid_extensions = %w(.erb .haml .liquid .builder)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, 'assets/tpl_file.png')}"
  end
end

class HtmlFile < TextFile
  self.file_type = :html
  self.content_type = 'text/html'
  self.valid_extensions = %w(.html .HTML)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/html_file.png')}"
  end
end

class XmlFile < TextFile
  self.file_type = :xml
  self.content_type = 'text/plain'
  self.valid_extensions = %w(.xml .XML)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/xml_file.png')}"
  end
end

class DocFile < TextFile
  self.file_type = :doc
  self.content_type = 'application/msword'
  self.valid_extensions = %w(.doc .dot)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/doc_file.png')}"
  end
end

class DocxFile < TextFile
  self.file_type = :docx
  self.content_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  self.valid_extensions = %w(.docx)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/docx_file.png')}"
  end
end

class Xls < TextFile
  self.file_type = :xls
  self.content_type = 'application/vnd.ms-excel'
  self.valid_extensions = %w(.xls .xlt .xla .xlsx)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/xls_file.png')}"
  end
end

class Ppt < TextFile
  self.file_type = :ppt
  self.content_type = 'application/vnd.ms-powerpoint'
  self.valid_extensions = %w(.ppt .pot .pps .ppa)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, 'assets/ppt_file.png')}"
  end
end

class Pptx < TextFile
  self.file_type = :pptx
  self.content_type = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  self.valid_extensions = %w(.pptx)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, 'assets/pptx_file.png')}"
  end
end

class Pdf < TextFile
  self.file_type = :pdf
  self.content_type = 'application/pdf'
  self.valid_extensions = %w(.pdf .PDF)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/pdf_file.png')}"
  end
end

class Swf < FileAsset
  self.file_type = :swf
  self.content_type = 'application/x-shockwave-flash'
  self.valid_extensions = %w(.swf .SWF)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/shockwave_file.png')}"
  end
end

class Mp3 < FileAsset
  self.file_type = :mp3
  self.content_type = 'audio/mpeg'
  self.valid_extensions = %w(.mp3)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/shockwave_file.png')}"
  end
end

class Wav < FileAsset
  self.file_type = :wav
  self.content_type = 'audio/wav'
  self.valid_extensions = %w(.wav)

  def thumbnail_src
    "#{ErpTechSvcs::Config.file_protocol}://#{File.join(ErpTechSvcs::Config.installation_domain, '/assets/shockwave_file.png')}"
  end
end

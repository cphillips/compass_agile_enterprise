class Report < ActiveRecord::Base
  attr_protected :created_at, :updated_at
  attr_accessible :name, :internal_identifier

  validates :name, :internal_identifier, :uniqueness => true

  before_create :set_default_template

  after_create :create_report_files!

  before_destroy :delete_report_files!

  has_file_assets

  has_party_roles

  is_json :meta_data

  REPORT_STRUCTURE = ['stylesheets', 'javascripts', 'images', 'templates']

  class << self
    def iid(internal_identifier)
      find_by_internal_identifier(internal_identifier)
    end

    def import(file)
      ActiveRecord::Base.transaction do
        result = validate_import?(file)

        if result[:valid]
          Report.skip_callback(:create, :after, :create_report_files!)

          if result[:type] == :multiple
            tmp_dir = Report.make_tmp_dir

            Zip::ZipFile.open(file.path) do |zip|
              zip.entries.each do |entry|
                ::File.open(tmp_dir + entry.name, 'wb+') { |f| entry.get_input_stream { |io| f.puts io.read } }

                name_and_iid = entry.name.to_s.gsub(/(^.*(\\|\/))|(\.zip$)/, '')
                report_name = name_and_iid.split('[').first
                report_iid = name_and_iid.split('[').last.gsub(']', '')

                if Report.where(internal_identifier: report_iid).first
                  Report.where(internal_identifier: report_iid).first.destroy
                end

                report = Report.create(:name => report_name, :internal_identifier => report_iid)
                report.import(::File.open(tmp_dir + entry.name))

                FileUtils.rm_f(tmp_dir + entry.name)
              end
            end
          else
            name_and_iid = file.original_filename.to_s.gsub(/(^.*(\\|\/))|(\.zip$)/, '')
            report_name = name_and_iid.split('[').first
            report_iid = name_and_iid.split('[').last.gsub(']', '')

            report = Report.create(:name => report_name, :internal_identifier => report_iid)
            report.import(file)
          end

          Report.set_callback(:create, :after, :create_report_files!)

        else
          false
        end
      end
    end

    def make_tmp_dir
      Pathname.new(Rails.root.to_s + "/tmp/reports/tmp_#{Time.now.to_i.to_s}/").tap do |dir|
        FileUtils.mkdir_p(dir) unless dir.exist?
      end
    end

    def validate_import?(file)
      result = {valid: false}

      Zip::ZipFile.open(file.path) do |zip|
        # check if this is a zip of report exports
        if zip.entries.find{|item| item.name.include?('.zip')}
          result[:type] = :multiple
          # make sure there are only zip files in here
          if zip.entries.collect{|item| File.extname(item.name)}.uniq == ['.zip']
            result[:valid] = true
          end
        else
          result[:type] = :single
          # valid the report zip
          zip.sort.each do |entry|
            entry.name.split('/').each do |_file|
              result[:valid] = true if REPORT_STRUCTURE.include?(_file)
            end
          end
        end
      end

      result
    end
  end

  def base_dir
    "#{Rails.root}/public/compass_ae_reports/#{self.internal_identifier}"
  end

  def url
    "/public/compass_ae_reports/#{self.internal_identifier}"
  end

  def import(file)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
    file = ActionController::UploadedTempfile.new("uploaded-report").tap do |f|
      f.puts file.read
      f.original_filename = file.original_filename
      f.read # no idea why we need this here, otherwise the zip can't be opened
    end unless file.path

    Zip::ZipFile.open(file.path) do |zip|
      zip.each do |entry|
        if entry.name.split('/').last == 'base.html.erb'
          name = entry.name.sub(/__MACOSX\//, '')
          data = ''
          entry.get_input_stream { |io| data = io.read }
          self.template = data
          self.save
          self.add_file(self.template, File.join(self.url, 'templates', "base.html.erb"))
        elsif entry.name.split('/').last == 'meta_data.yml'
          data = ''
          entry.get_input_stream { |io| data = io.read }
          data = StringIO.new(data) if data.present?
          self.meta_data = YAML.load(data)
          self.save
        elsif entry.name.split('/').last == 'query.sql'
          data = ''
          entry.get_input_stream { |io| data = io.read }
          self.query = data
          self.save
        else
          if entry.file?
            name = entry.name.sub(/__MACOSX\//, '')
            data = ''
            entry.get_input_stream { |io| data = io.read }
            data = StringIO.new(data) if data.present?
            report_file = self.files.where("name = ? and directory = ?", File.basename(name), File.join(self.url, File.dirname(name))).first
            unless report_file.nil?
              report_file.data = data
              report_file.save
            else
              self.add_file(data, File.join(file_support.root, self.url, name))
            end
          end
        end
      end
    end

  end

  def export
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
    tmp_dir = Report.make_tmp_dir
    (tmp_dir + "#{name}[#{internal_identifier}].zip").tap do |file_name|
      file_name.unlink if file_name.exist?
      Zip::ZipFile.open(file_name.to_s, Zip::ZipFile::CREATE) do |zip|
        files.each do |file|
          contents = file_support.get_contents(File.join(file_support.root, file.directory, file.name))
          relative_path = file.directory.sub("#{url}", '')
          path = FileUtils.mkdir_p(File.join(tmp_dir, relative_path))
          full_path = File.join(path, file.name)
          File.open(full_path, 'wb+') { |f| f.puts(contents) }
          zip.add(File.join(relative_path[1..relative_path.length], file.name), full_path) if ::File.exists?(full_path)
        end
        ::File.open(tmp_dir + 'query.sql', 'wb+') { |f| f.puts(query) }
        zip.add('query.sql', tmp_dir + 'query.sql')
        ::File.open(tmp_dir + 'meta_data.yml', 'wb+') { |f| f.puts(meta_data.to_yaml) }
        zip.add('meta_data.yml', tmp_dir + 'meta_data.yml')

      end
    end
  end

  def stylesheet_path(source)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    File.join(file_support.root, self.url, 'stylesheets', source)
  end

  def image_path(source)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    File.join(file_support.root, self.url, 'images', source)
  end

  def template_path(source)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    File.join(file_support.root, self.url, 'templates', source)
  end

  def javascript_path(source)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    File.join(file_support.root, self.url, 'javascripts', source)
  end

  def create_report_files!
    self.add_file(self.template, File.join(self.url, 'templates', "base.html.erb"))
    self.add_file(self.default_stylesheet,File.join(self.url, 'stylesheets', "#{self.internal_identifier}.css") )
  end

  def delete_report_files!
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)
    file_support.delete_file(File.join(file_support.root, self.url), :force => true)
  end

  def set_default_template
    self.template =
    "<%= bootstrap_load %>
  <%= report_stylesheet_link_tag '#{self.internal_identifier}','#{self.internal_identifier}.css' %>
<h3> <%= title %> </h3>
<table>
  <thead>
    <tr>
    <% columns.each do |column| %>
      <th> <%= column %> </th>
    <% end %>
    </tr>
  </thead>
  <% rows.each do |row| %>
    <tr>
      <% row.values.each do |value| %>
            <td> <%= value %> </td>
      <% end %>
    </tr>
  <% end %>
</table>
<%= jquery_load %>"
  end

  def default_stylesheet
    "body{
  padding: 5px; 
}

table{
  width: 100%;
}

table tr{
  page-break-inside: avoid !important;
}

table th{
  border: 1px solid black;
  color: white;
  border-collapse:collapse;
  font-size: 16px;
  vertical-align:center;
  text-align: center;
  background-color: 537697;
  padding-top: 2px;
  padding-bottom: 2px;
  padding-left: 15px;
  padding-right: 15px;

}

table td{
  border: 1px solid black;
  border-collapse:collapse;
  font-size: 14px;
  vertical-align:top;
  padding-top: 2px;
  padding-left: 15px;
  padding-right: 15px;
}

td.no-border {
    border: 0px;
    height: 20px;
}

.bold{
    font-weight: bold;
    height: 20px;
}

.left-padded{
    padding-left: 20px;
}"
  end

end

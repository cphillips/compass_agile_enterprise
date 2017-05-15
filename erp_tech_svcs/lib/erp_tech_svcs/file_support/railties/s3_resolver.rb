module ActionView
  class S3Resolver < PathResolver
    def initialize(path, pattern=nil)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super(pattern)
      @path = path
    end

    def to_s
      @path.to_s
    end
    alias :to_path :to_s

    def eql?(resolver)
      self.class.equal?(resolver.class) && to_path == resolver.to_path
    end
    alias :== :eql?

    def cached(key, path_info, details, locals) #:nodoc:
      name, prefix, partial = path_info
      locals = locals.map { |x| x.to_s }.sort!

      if key && caching?
        if @cached[key][name][prefix][partial][locals].nil? or @cached[key][name][prefix][partial][locals].empty?
          @cached[key][name][prefix][partial][locals] = decorate(yield, path_info, details, locals)
        else
          @cached[key][name][prefix][partial][locals].each do |template|
            file_asset = FileAsset.select('data_updated_at').where('directory = ? and data_file_name = ?', File.dirname(template.identifier), template.identifier.split('/').last).first

            #check if the file still exists
            if file_asset
              if file_asset.data_updated_at > template.updated_at
                @cached[key][name][prefix][partial][locals].delete_if{|item| item.identifier == template.identifier}
                @cached[key][name][prefix][partial][locals] << build_template(template.identifier, template.virtual_path, (details[:formats] || [:html] if template.formats.empty?), file_support, template.locals)
              end
            else
              @cached[key][name][prefix][partial][locals].delete_if{|item| item.identifier == template.identifier}
            end
          end
          @cached[key][name][prefix][partial][locals]
        end
      else
        fresh = decorate(yield, path_info, details, locals)
        return fresh unless key

        scope = @cached[key][name][prefix][partial]
        cache = scope[locals]
        _mtime = cache && cache.map(&:updated_at).max

        if !_mtime || fresh.empty?  || fresh.any? { |t| t.updated_at > _mtime }
          scope[locals] = fresh
        else
          cache
        end
      end
    end

    def query(path, details, formats, outside_app_allowed=nil)
      templates = []
      get_dir_entries(path).each{|p|templates << build_template(p, path.virtual, formats)}
      templates
    end

    def get_dir_entries(path)
      full_path = File.join(@path, path)

      file_asset = FileAsset.where("concat(directory, '/', name) ilike ?", full_path + '%').first

      (file_asset ? [File.join(file_asset.directory, file_asset.data_file_name)] : [])
    end

    protected

    def build_template(p, virtual_path, formats, locals=nil)
      handler, format = extract_handler_and_format(p, formats)

      file_asset = FileAsset.where("concat(directory, '/', name) ilike ?", p + '%').first

      contents, message = file_asset.get_contents

      Template.new(contents, p, handler, :virtual_path => virtual_path, :format => format, :updated_at => file_asset.data_updated_at, :locals => locals)
    end
  end
end

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
      file_support = ErpTechSvcs::FileSupport::Base.new(:storage => :s3)
      name, prefix, partial = path_info
      locals = locals.map { |x| x.to_s }.sort!

      if key && caching?
        if @cached[key][name][prefix][partial][locals].nil? or @cached[key][name][prefix][partial][locals].empty?
          @cached[key][name][prefix][partial][locals] = decorate(yield, path_info, details, locals)
        else
          @cached[key][name][prefix][partial][locals].each do |template|
            #check if the file still exists
            if file_support.exists? template.identifier
              if mtime(template.identifier) > template.updated_at
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
      file_support = ErpTechSvcs::FileSupport::Base.new(:storage => :s3)
      templates = []
      get_dir_entries(path, file_support).each{|p|templates << build_template(p, path.virtual, formats, file_support)}
      templates
    end

    def get_dir_entries(path, file_support)
      full_path = File.join(@path, path)
      node = file_support.find_node(File.dirname(full_path))
      node.nil? ? [] : node[:children].select{|child| child[:leaf]}.collect{|child| child[:id]}.select{|p|!p.scan(full_path).empty?}
    end

    def mtime(p)
      p = p.sub(%r{^/}, '')
      ErpTechSvcs::FileSupport::S3Manager.new.bucket.objects[p].last_modified
    end

    protected

    def build_template(p, virtual_path, formats, file_support, locals=nil)
      handler, format = extract_handler_and_format(p, formats)
      contents, message = file_support.get_contents(p)

      Template.new(contents, p, handler, :virtual_path => virtual_path, :format => format, :updated_at => mtime(p), :locals => locals)
    end
  end
end

module ErpTechSvcs
  module FileSupport
    class FileSystemManager < Manager
      REMOVE_FILES_REGEX = /^\./

      def root
        Rails.root.to_s
      end

      def replace_file(old_path, new_path, contents)
        create_name = File.basename(new_path);
        create_path = new_path.split('/').reverse.drop(1).reverse.join('/')

        create_file(create_path, create_name, contents)
        delete_file(old_path)
      end

      def update_file(path, content)
        File.open(path, 'wb+') { |f| f.write(content) }
      end

      def create_file(path, name, contents)
        FileUtils.mkdir_p path unless File.exists? path
        File.open(File.join(path, name), 'wb+') { |f| f.write(contents) }
      end

      # copy a file
      def copy_file(origination_file, path, name)
        contents = get_contents(origination_file)

        create_file(path, name, contents)
      end

      def create_folder(path, name)
        unless File.directory? File.join(path, name)
          FileUtils.mkdir_p File.join(path, name)
        end
      end

      def save_move(path, new_parent_path)
        old_path = File.join(path)
        new_path = File.join(Rails.root, new_parent_path)
        result = false
        unless File.exists? old_path
          message = FILE_DOES_NOT_EXIST
        else
          name = File.basename(path)
          #make sure path is there.
          FileUtils.mkdir_p new_path unless File.directory? new_path
          FileUtils.mv(old_path, File.join(new_path, name))
          message = "#{name} was moved to #{new_parent_path} successfully"
          result = true
        end

        return result, message
      end

      def exists?(path)
        File.exists? path
      end

      def rename_file(path, name)
        result = false
        unless File.exists? path
          message = FILE_DOES_NOT_EXIST
        else
          old_name = File.basename(path)
          path_pieces = path.split('/')
          path_pieces.delete(path_pieces.last)
          path_pieces.push(name)
          new_path = path_pieces.join('/')
          File.rename(path, new_path)
          message = "#{old_name} was renamed to #{name} successfully"
          result = true
        end

        return result, message
      end

      def delete_file(path, options={})
        result = false
        name = File.basename(path)
        is_directory = false
        if !File.exists? path and !File.directory? path
          message = FILE_FOLDER_DOES_NOT_EXIST
        else
          if File.directory? path
            is_directory = true
            entries = Dir.entries(path)
            entries.delete_if { |entry| entry =~ REMOVE_FILES_REGEX }
            if entries.count > 0 && !options[:force]
              message = FOLDER_IS_NOT_EMPTY
              result = false
            else
              FileUtils.rm_rf(path)

              child_files = FileAsset.where(FileAsset.arel_table[:directory].matches("#{path.gsub(root, '')}%"))
              child_files.each do |file|
                file.destroy
              end

              message = "Folder #{name} was deleted #{name} successfully"
              result = true
            end
          else
            FileUtils.rm_rf(path)
            message = "File #{name} was deleted #{name} successfully"
            result = true
          end
        end

        return result, message, is_directory
      end

      def get_contents(path)
        contents = nil
        message = nil
        unless File.exists? path
          message = FILE_DOES_NOT_EXIST
        else
          contents = File.open(path, 'rb') { |file| file.read }
        end
        return contents, message
      end

      def build_tree(starting_path, options={})
        find_node(starting_path, options)
      end

      def find_node(path, options={})
        if options[:file_asset_holder]
          super
        else
          if File.exists? path
            if File.directory? path
              path_pieces = path.split('/')
              parent = build_tree_for_directory(path, options)
              unless parent[:id] == path
                path_pieces.each do |path_piece|
                  next if path_piece.blank?
                  parent[:children].each do |child_node|
                    if child_node[:text] == path_piece
                      parent = child_node
                      break
                    end
                  end
                end
              end

              parent = nil if parent[:id] != path
              parent
            else
              build_node(path, options)
            end
          else
            nil
          end
        end
      end

      def build_node(path, options={})
        if File.directory?(path)
          if options[:preload]
            build_tree_for_directory(path, options) if options[:preload]
          else
            path.gsub!(root, '') unless options[:keep_full_path]

            {:text => path.split('/').last, :id => path, :iconCls => 'icon-content'}
          end
        else
          path.gsub!(root, '') unless options[:keep_full_path]

          parts = path.split('/')
          parts.pop
          download_path = parts.join('/')

          if !options[:included_file_extensions_regex].nil? && entry =~ options[:included_file_extensions_regex]
            {:text => path.split('/').last, :leaf => true, :iconCls => 'icon-document', :downloadPath => download_path, :id => path}
          elsif options[:included_file_extensions_regex].nil?
            {:text => path.split('/').last, :leaf => true, :iconCls => 'icon-document', :downloadPath => download_path, :id => path}
          end

        end
      end

      private

      def build_tree_for_directory(directory, options)
        if options[:keep_full_path] != false and !directory.index(root).nil?
          options[:keep_full_path] = true
        end

        tree_data = {
            :text => directory.split('/').last,
            :iconCls => File.directory?(directory) ? 'icon-content' : 'icon-document',
            :id => directory,
            :leaf => !File.directory?(directory),
            :children => []
        }

        tree_data[:id].gsub!(root, '') unless options[:keep_full_path]

        Dir.entries(directory).each do |entry|
          #ignore .svn folders and any other folders starting with .
          next if entry =~ REMOVE_FILES_REGEX

          tree_data[:children] << build_node(File.join(directory, entry), options)

        end if File.directory?(directory)

        tree_data[:children].sort_by! { |item| [item[:text]] }
        tree_data
      end

    end #FileSystemManager
  end #FileSupport
end #ErpTechSvcs
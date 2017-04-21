CollectiveIdea::Acts::NestedSet::Model.class_eval do
  protected

  # Prunes a branch off of the tree, shifting all of the elements on the right
  # back to the left so the counts still work.
  def destroy_descendants
    return if right.nil? || left.nil? || skip_before_destroy

    in_tenacious_transaction do
      # Rescue from +ActiveRecord::RecordNotFound+ error as there may be a case
      # that an +object+ has already been destroyed by its parent, but objects that are
      # in memory are not aware about this.
      begin
        reload_nested_set
      rescue ActiveRecord::RecordNotFound
        self.skip_before_destroy = true
        return true
      end

      # select the rows in the model that extend past the deletion point and apply a lock
      nested_set_scope.where(["#{quoted_left_column_full_name} >= ?", left]).
        select(id).lock(true)

      if acts_as_nested_set_options[:dependent] == :destroy
        descendants.each do |model|
          model.skip_before_destroy = true
          model.destroy
        end
      else
        nested_set_scope.where(["#{quoted_left_column_name} > ? AND #{quoted_right_column_name} < ?", left, right]).
          destroy_all
      end

      # update lefts and rights for remaining nodes
      diff = right - left + 1
      nested_set_scope.where(["#{quoted_left_column_full_name} > ?", right]).update_all(
        ["#{quoted_left_column_name} = (#{quoted_left_column_name} - ?)", diff]
      )

      nested_set_scope.where(["#{quoted_right_column_full_name} > ?", right]).update_all(
        ["#{quoted_right_column_name} = (#{quoted_right_column_name} - ?)", diff]
      )

      # Don't allow multiple calls to destroy to corrupt the set
      self.skip_before_destroy = true
    end
  end

end

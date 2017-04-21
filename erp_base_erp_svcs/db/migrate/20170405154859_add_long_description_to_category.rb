class AddLongDescriptionToCategory < ActiveRecord::Migration
  def up
    unless column_exists? :categories, :long_description
      add_column :categories, :long_description, :text
    end
  end

  def down
    if column_exists? :categories, :long_description
      remove_column :categories, :long_description
    end
  end
end

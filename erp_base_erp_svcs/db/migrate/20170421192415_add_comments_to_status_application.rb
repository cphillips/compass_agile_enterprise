class AddCommentsToStatusApplication < ActiveRecord::Migration
  def up
    add_column :status_applications, :comments, :string unless column_exists? :status_applications, :comments
  end

  def down
    remove_column :status_applications, :comments if column_exists? :status_applications, :comments
  end
end

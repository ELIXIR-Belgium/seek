class IncreaseGitVersionResourceAttributesLength < ActiveRecord::Migration[6.1]
  def up
    change_column :git_versions, :resource_attributes, :text, limit: 16.megabytes - 1
  end

  def def down
    change_column :git_versions, :resource_attributes
  end
end

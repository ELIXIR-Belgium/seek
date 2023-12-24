class SetDefaultOnTemplatesColumns < ActiveRecord::Migration[5.2]
  def up
    change_column :templates, :level, :string, :default => "other"
    change_column :templates, :organism, :string, :default => "other"
    change_column :templates, :group, :string, :default => "other"
  end

  def down
    change_column :templates, :level, :string
    change_column :templates, :organism, :string
    change_column :templates, :group, :string
  end
end

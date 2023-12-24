class RemoveRepositoryStandardIdFromSampleCv< ActiveRecord::Migration[5.2]
  def up
    remove_column :sample_controlled_vocabs, :repository_standard_id
  end

  def down
    add_column :sample_controlled_vocabs, :repository_standard_id, :integer
  end
end

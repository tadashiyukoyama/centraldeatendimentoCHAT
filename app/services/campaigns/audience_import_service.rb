class Campaigns::AudienceImportService
  MAX_FILE_SIZE = 10.megabytes

  pattr_initialize [:account!, :user!, :name!, :import_file!]

  def perform
    validate!

    ActiveRecord::Base.transaction do
      create_import!
      create_internal_label!
      attach_file!
      data_import
    end
  end

  private

  attr_reader :data_import, :label

  def validate!
    raise ArgumentError, 'Informe um nome para a lista.' if name.to_s.strip.blank?
    raise ArgumentError, 'Selecione um arquivo CSV.' if import_file.blank?
    raise ArgumentError, 'A lista deve ser um arquivo CSV.' unless File.extname(import_file.original_filename.to_s).casecmp?('.csv')
    raise ArgumentError, 'O arquivo CSV deve ter no máximo 10 MB.' if import_file.size.to_i > MAX_FILE_SIZE
  end

  def create_import!
    @data_import = account.data_imports.create!(
      data_type: 'contacts',
      name: name.to_s.strip,
      initiated_by: user,
      source_type: 'csv',
      source_metadata: {
        DataImport::CAMPAIGN_AUDIENCE_KIND_KEY => DataImport::CAMPAIGN_AUDIENCE_KIND
      }
    )
  end

  def create_internal_label!
    @label = account.labels.create!(
      title: "campaign_list_#{data_import.id}",
      description: "Lista de campanha: #{data_import.name}",
      color: '#2563EB',
      show_on_sidebar: false
    )
    data_import.update!(
      source_metadata: data_import.source_metadata.merge(
        DataImport::CAMPAIGN_AUDIENCE_LABEL_ID_KEY => label.id
      )
    )
  end

  def attach_file!
    data_import.import_file.attach(import_file)
  end
end

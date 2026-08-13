class Api::V1::Accounts::CampaignAudiencesController < Api::V1::Accounts::BaseController
  before_action :authorize_campaign_audiences

  def index
    render json: campaign_audience_imports.map { |data_import| audience_payload(data_import) }
  end

  def create
    data_import = Campaigns::AudienceImportService.new(
      account: Current.account,
      user: current_user,
      name: params[:name],
      import_file: params[:import_file]
    ).perform

    render json: audience_payload(data_import), status: :accepted
  rescue ArgumentError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_campaign_audiences
    authorize Campaign, action_name == 'index' ? :index? : :create?
  end

  def campaign_audience_imports
    Current.account.data_imports
           .where('source_metadata ->> ? = ?', DataImport::CAMPAIGN_AUDIENCE_KIND_KEY, DataImport::CAMPAIGN_AUDIENCE_KIND)
           .order(created_at: :desc)
  end

  def audience_payload(data_import)
    label = Current.account.labels.find_by(id: data_import.campaign_audience_label_id)

    {
      id: data_import.id,
      name: data_import.name,
      label_id: label&.id,
      status: data_import.status,
      contact_count: audience_contact_count(label),
      imported_count: data_import.processed_records.to_i,
      rejected_count: rejected_count(data_import),
      total_count: data_import.total_records.to_i,
      filename: data_import.import_file.attached? ? data_import.import_file.filename.to_s : nil,
      created_at: data_import.created_at.iso8601
    }
  end

  def audience_contact_count(label)
    label ? Current.account.contacts.tagged_with(label.title).count : 0
  end

  def rejected_count(data_import)
    [data_import.total_records.to_i - data_import.processed_records.to_i, 0].max
  end
end

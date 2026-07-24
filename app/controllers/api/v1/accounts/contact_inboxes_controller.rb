class Api::V1::Accounts::ContactInboxesController < Api::V1::Accounts::BaseController
  before_action :ensure_inbox

  def filter
    contact_inbox = @inbox.contact_inboxes.where(inbox_id: permitted_params[:inbox_id], source_id: permitted_params[:source_id])
    return head :not_found if contact_inbox.empty?

    contacts = Contacts::PermissionFilterService.new(
      Current.account.contacts.where(id: contact_inbox.first.contact_id),
      Current.user,
      Current.account
    ).perform
    @contact = contacts.first
    head :not_found if @contact.blank?
  end

  private

  def ensure_inbox
    @inbox = Current.account.inboxes.find(permitted_params[:inbox_id])
    authorize @inbox, :show?
  end

  def permitted_params
    params.permit(:inbox_id, :source_id)
  end
end

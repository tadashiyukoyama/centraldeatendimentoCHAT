class Api::V1::Openjarvis::ContactsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('contacts:read')
    records = openjarvis_access_scope.contacts
    records = search(records) if params[:q].present?
    page = cursor_page(records, type: cursor_type('contacts', q: params[:q]))
    render json: { data: page.records.map { |contact| present(contact) }, meta: page.meta }
  end

  def show
    require_scope!('contacts:read')
    render json: { data: present(openjarvis_access_scope.contact!(params[:id])) }
  end

  def create
    require_scope!('contacts:write')
    validate_contact_params!
    execute_idempotently('contacts.create', contact_params) do
      contact = matching_contact
      if contact && !openjarvis_access_scope.contacts.exists?(id: contact.id)
        raise Openjarvis::ApiError.new('contact_conflict', 'A matching contact exists outside the authorized scope', status: :conflict)
      end

      status = contact ? :ok : :created
      contact ||= Current.account.contacts.new
      contact.assign_attributes(contact_params)
      contact.save!
      idempotent_result(status: status, body: { data: present(contact) }, resource: contact)
    end
  end

  def update
    require_scope!('contacts:write')
    contact = openjarvis_access_scope.contact!(params[:id])
    validate_contact_params!
    execute_idempotently('contacts.update', contact_params.merge(id: contact.id)) do
      contact.update!(contact_params)
      idempotent_result(status: :ok, body: { data: present(contact) }, resource: contact)
    end
  end

  private

  def contact_params
    params.require(:contact).permit(
      :name, :email, :phone_number, :identifier, :contact_type,
      additional_attributes: {}, custom_attributes: {}
    )
  end

  def matching_contact
    attributes = contact_params
    return Current.account.contacts.find_by(identifier: attributes[:identifier]) if attributes[:identifier].present?

    if attributes[:email].present?
      contact = Current.account.contacts.where('LOWER(email) = ?', attributes[:email].downcase).first
      return contact if contact
    end
    return Current.account.contacts.find_by(phone_number: attributes[:phone_number]) if attributes[:phone_number].present?

    nil
  end

  def validate_contact_params!
    validate_enum_value!(Contact, :contact_type, contact_params[:contact_type])
  end

  def search(scope)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
    scope.where('name ILIKE :term OR email ILIKE :term OR phone_number ILIKE :term OR identifier ILIKE :term', term: term)
  end

  def present(contact)
    Openjarvis::ContactPresenter.new(contact).as_json
  end
end

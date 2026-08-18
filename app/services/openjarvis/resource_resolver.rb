class Openjarvis::ResourceResolver
  def initialize(access_scope)
    @access_scope = access_scope
    @account = access_scope.account
    @user = access_scope.user
  end

  def agents(inbox: nil)
    records = if inbox
                inbox.assignable_agents
              elsif administrator?
                account.users.to_a
              else
                ([user] + user.teams.includes(:members).flat_map(&:members)).uniq
              end
    records.select { |record| account.account_users.exists?(user_id: record.id) }.sort_by { |record| [record.name.to_s.downcase, record.id] }
  end

  def teams
    scope = account.teams.order(:name, :id)
    administrator? ? scope : scope.where(id: user.teams.select(:id))
  end

  def labels
    account.labels.order(:title, :id)
  end

  def agent!(id, inbox:)
    agent = agents(inbox: inbox).find { |record| record.id == id.to_i }
    return agent if agent

    raise Openjarvis::ApiError.new('assignee_not_authorized', 'Assignee is not assignable to this inbox', status: :forbidden)
  end

  def team!(id)
    team = teams.find_by(id: id)
    return team if team

    raise Openjarvis::ApiError.new('team_not_authorized', 'Team is outside the service user scope', status: :forbidden)
  end

  def label_titles!(titles)
    normalized = Array(titles).map(&:to_s).map(&:downcase).uniq
    existing = labels.where(title: normalized).pluck(:title)
    missing = normalized - existing
    if missing.any?
      raise Openjarvis::ApiError.new('label_not_found', 'One or more labels do not exist', status: :unprocessable_entity,
                                                                                           details: { labels: missing })
    end

    normalized
  end

  private

  attr_reader :access_scope, :account, :user

  def administrator?
    access_scope.configuration.account_user&.administrator?
  end
end

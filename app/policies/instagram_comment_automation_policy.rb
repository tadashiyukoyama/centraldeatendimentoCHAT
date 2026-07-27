class InstagramCommentAutomationPolicy < ApplicationPolicy
  def index?
    administrator?
  end

  def show?
    administrator?
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  def destroy?
    administrator?
  end

  private

  def administrator?
    @account_user&.administrator?
  end
end

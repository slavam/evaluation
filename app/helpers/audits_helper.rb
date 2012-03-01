module AuditsHelper
  def audit_action_in_past(action)
    return action + 'd' if action == 'create' or action == 'update'
    return action + 'ed' if action == 'destroy'
  end
end

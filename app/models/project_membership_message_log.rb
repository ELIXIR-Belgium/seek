class ProjectMembershipMessageLog < MessageLog

  default_scope { where(message_type: PROJECT_MEMBERSHIP_REQUEST) }
  scope :pending_project_join_requests, ->(projects) { where(subject: projects).pending }

  validate :project_required_for_project_membership_request

  # message logs created since the recent period, for that person and project
  scope :recent_project_membership_requests, lambda { |person, project|
    where(subject: project).where(sender: person).recent
  }

  # records a project membership request for a sender and project, along with any details provided
  def self.log_project_membership_request(sender, project, institution, comments)
    details = { comments: comments }
    details[:institution] = institution.attributes if institution
    ProjectMembershipMessageLog.create(subject: project, sender: sender, details: details.to_json)
  end

  private

  def project_required_for_project_membership_request
    if message_type == PROJECT_MEMBERSHIP_REQUEST && !subject.is_a?(Project)
      errors.add(:subject, 'must be a project for a project membership request')
    end
  end
end
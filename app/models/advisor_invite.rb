class AdvisorInvite < ApplicationRecord
  belongs_to :family
  belongs_to :created_by, class_name: "User", optional: true

  TTL = 30.days

  validates :expires_at, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.lookup(id)
    return if id.blank?

    active.find_by(id: id)
  end

  def self.issue!(family:, created_by:, email: nil, name: nil)
    family.advisor_invites.create!(
      created_by: created_by,
      email: email.to_s.strip.downcase.presence,
      name: name.to_s.strip.presence,
      expires_at: TTL.from_now
    )
  end

  def active?
    revoked_at.nil? && expires_at > Time.current
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_viewed!
    update_column(:last_viewed_at, Time.current)
  end
end

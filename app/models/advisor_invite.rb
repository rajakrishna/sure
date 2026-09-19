class AdvisorInvite < ApplicationRecord
  belongs_to :family
  belongs_to :created_by, class_name: "User", optional: true

  TTL = 30.days

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  attr_accessor :raw_token

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.lookup(token)
    return if token.blank?

    active.find_by(token_digest: digest(token))
  end

  def self.issue!(family:, created_by:, email: nil, name: nil)
    token = SecureRandom.urlsafe_base64(32)
    invite = family.advisor_invites.create!(
      created_by: created_by,
      email: email.to_s.strip.downcase.presence,
      name: name.to_s.strip.presence,
      token_digest: digest(token),
      expires_at: TTL.from_now
    )
    invite.raw_token = token
    invite
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

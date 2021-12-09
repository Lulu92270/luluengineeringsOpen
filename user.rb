class User < ApplicationRecord
  before_create :confirmation_token
  after_initialize do
    if self.new_record?
      self.increment_premium(1)
      self.favourite_tool = schema_array.map{ |tool, index| {"favourite": false, "schemaRef": tool} }.to_json
    end
  end

  has_secure_password
  has_many :pressure_drops, dependent: :destroy
  has_many :expansion_vessels, dependent: :destroy
  has_many :combustion_performances, dependent: :destroy
  has_many :ventilations, dependent: :destroy
  has_many :steams, dependent: :destroy
  has_many :cables, dependent: :destroy
  has_many :insulations, dependent: :destroy
  has_many :pump_curves, dependent: :destroy
  has_many :pumps, dependent: :destroy
  
  EMAIL_CHECK = /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z/
  PASSWORD_CHECK = /\A(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%\^&\*])(?=.{8,})/

  validates_format_of :email, with: EMAIL_CHECK, message: 'wrong email format'
  validates_format_of :password, with: PASSWORD_CHECK, message: 'wrong password format', if: :password_required?
  validates :password, length: { minimum: 6 }, :if => :password
  validates_presence_of :email, :password, :on => :create
  validates_uniqueness_of :email, message: 'this email already exists'
  validates_length_of :full_name, :password, :password_confirmation, :email, maximum: 80
  validates_length_of :react_grid_layout_data, maximum: 5000
  validates_length_of :company_logo_url, maximum: 300
  validates_length_of :favourite_tool, maximum: 1000
  validates :pdf_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3 }

  def enforce_password_validation
    @enforce_password_validation = true
  end
  # EMAIL CONFIRMATION SECTION
  def email_activate
    self.email_confirmed = true
    self.confirm_token = nil
    save!(:validate => false)
  end
  # EMAIL ACTIVATION SECTION
  def send_account_activate
    self.confirm_token = generate_base64_token
    save!(:validate => false)
    UserMailer.is_account_active_confirmation(self).deliver_now
  end
  def account_activate
    self.is_account_active = true
    self.confirm_token = nil
    save!
  end
  # RESET PASSWORD SECTION
  def send_password_reset
    self.confirm_token = generate_base64_token
    self.password_reset_sent_at = Time.zone.now
    save!(:validate => false)
    UserMailer.password_reset(self).deliver_now
  end
  def password_token_valid?
    (self.password_reset_sent_at + 1.hour) > Time.zone.now
  end
  def reset_password(password)
    self.confirm_token = nil
    self.password = password
    save!
  end
  # PROJECT SECTION
  def project_count
    counter = 0
    tool_array.each do |tool|
      counter += tool.constantize.where(user: self).count ? tool.constantize.where(user: self).count : 0
    end
    counter
  end
  def can_create_project?
    no_project = project_count
    counter = self.is_premium? ? ENV["MAX_PROJECT_PREMIUM"].to_i - no_project : ENV["MAX_PROJECT_STANDARD"].to_i - no_project
    self.create_project = counter.positive?
    self.save!
    counter.positive?
  end
  def can_update_project?(date_project)
    if self.is_premium?
      return true
    else
      array = []
      tool_array.each do |model|
        tool_array = model.constantize.where(user: self)
        tool_array.each do |tool|
          array << tool
        end
      end
      if array.count <= ENV["MAX_PROJECT_STANDARD"].to_i
        return true
      end
      date_array = array.map { |tool| tool.attributes.slice('updated_at')["updated_at"] }
      return date_project > date_array.sort.reverse![ENV["MAX_PROJECT_STANDARD"].to_i]
    end
  end
  # PDF SECTION
  def refresh_pdf_limit_date
    self.pdf_date_refresh_limit = Date.today
    save!(:validate => false)
  end
  def check_pdf_date
    if self.pdf_limit == 0
      time_diff = (Time.current - self.pdf_date_refresh_limit)
      if (time_diff / 1.day).round > 7
        self.pdf_limit = 3
        self.save!
      end
    end
  end
  # PREMIUM SECTION
  def increment_premium(nb)
    if premium_until.nil? || (premium_until < Date.today)
      self.premium_until = Date.today
    end
    self.premium_until += (nb).month
    self.save!
  end
  def is_premium?
    if premium_until.nil?
      self.premium_until = Date.today + 1.month
      self.save!
    end
    self.premium_until >= Date.today 
  end
  private
  # EMAIL CONFIRMATION SECTION
  def confirmation_token
    if self.confirm_token.blank?
      self.confirm_token = SecureRandom.urlsafe_base64
    end
  end
  # RESET PASSWORD SECTION
  def generate_base64_token
    SecureRandom.urlsafe_base64
  end
  # FOR USER UPDATE
  def password_required?
    @enforce_password_validation || password.present?
  end
  def max_projects
    self.is_premium? ? ENV["MAX_PROJECT_PREMIUM"].to_i : ENV["MAX_PROJECT_STANDARD"].to_i
  end
  def tool_array
    [
      "PressureDrop",
      "ExpansionVessel",
      "Ventilation",
      "CombustionPerformance",
      "Steam",
      "Cable",
      "Insulation",
      "Pump",
      "PumpCurve"
    ]
  end
  def schema_array
    [
      "pressure_drops",
      "expansion_vessels",
      "ventilations",
      "combustion_performances",
      "steams",
      "cables",
      "insulations",
      "pumps",
      "pump_curves"
    ]
  end
end

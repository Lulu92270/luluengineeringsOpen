class CombustionPerformance < ApplicationRecord
  belongs_to :user

  validates :project_name, :revision, :edited_by, :checked_by, :approved_by, length: { maximum: 50 }
  validates :methane, :ethane, :propane, :butane, :pentane, :hexane, :carbon_dioxide, :carbon_monoxide, :nitrogen, :oxygen, :hydrogen,
            :exhaust_oxygen_content, :fuel_gas_used, :elec_output, :exhaust_temperature,
            :user_id, :created_at, :updated_at, presence: true, on: :update
end

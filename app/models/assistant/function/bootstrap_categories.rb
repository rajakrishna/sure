class Assistant::Function::BootstrapCategories < Assistant::Function
  class << self
    def name
      "bootstrap_categories"
    end

    def description
      <<~INSTRUCTIONS
        Creates Sure's default spending and income categories if they are missing.
        Safe to call repeatedly: existing names are left unchanged.

        Use when get_categories is empty, or before batch-categorizing a family
        that has no category tree yet.
      INSTRUCTIONS
    end
  end

  def call(_params = {})
    existing_ids = family.categories.pluck(:id)
    family.categories.bootstrap!
    created = family.categories.where.not(id: existing_ids).order(:name)

    {
      success: true,
      created_count: created.size,
      created: created.map { |category| serialize(category) },
      total_categories: family.categories.count,
      message: created.any? ? "Created #{created.size} default categories." : "Default categories already present."
    }
  end

  private
    def serialize(category)
      {
        id: category.id,
        name: category.name,
        name_with_parent: category.name_with_parent,
        color: category.color,
        icon: category.lucide_icon,
        parent_id: category.parent_id
      }
    end
end

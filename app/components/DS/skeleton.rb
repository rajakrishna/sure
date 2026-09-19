class DS::Skeleton < DesignSystemComponent
  def initialize(lines: 3, **opts)
    @lines = lines
    @opts = opts
  end

  erb_template <<~ERB
    <%= content_tag :div,
          class: class_names("space-y-2 animate-pulse", @opts[:class]),
          data: { testid: "ds-skeleton" },
          **@opts.except(:class) do %>
      <% @lines.times do |index| %>
        <div class="h-3 rounded-md bg-container-inset <%= index == @lines - 1 ? "w-2/3" : "w-full" %>"></div>
      <% end %>
    <% end %>
  ERB
end

ActiveAdmin.register Section do
  belongs_to :questionnaire

  # CanCan has trouble with embedded documents, so we may need to load and
  # authorize resources manually. In this case, we will authorize against
  # the top-level document.
  # @see https://github.com/ryanb/cancan/issues/319
  #
  # Since sections are scoped to the parent questionnaire, we don't necessarily
  # need to use #accessible_by to enforce constraints.
  #
  # https://github.com/ryanb/cancan/wiki/Controller-Authorization-Example
  controller do
    skip_authorize_resource :only => :index

    def index
      authorize! :show, parent
      index!
    end
  end

  index do
    column :title
    column :group do |s|
      t(s.group, scope: :group) if s.group?
    end
    column :questions do |s|
      s.questions.count
    end
    default_actions
  end

  form do |f|
    f.inputs do
      f.input :title
      f.input :group, collection: Section::GROUPS.map{|g| [t(g, scope: :group), g]}
      f.input :description, as: :text, input_html: {rows: 3}
      f.input :extra, as: :text, input_html: {rows: 3}
      f.input :embed, as: :text, input_html: {rows: 3}
    end

    # @see https://github.com/gregbell/active_admin/pull/1391
    f.has_many :questions, header: Question.model_name.human(count: 1.1) do |g,i|
      unless g.object.new_record?
        g.input :_destroy, as: :boolean
      end

      g.inputs t('legend.question') do
        g.input :title
        g.input :description, as: :text, input_html: {rows: 4}
        g.input :extra, as: :text, input_html: {rows: 2}
        g.input :embed, as: :text, input_html: {rows: 2}
        g.input :widget, collection: Question::WIDGETS.map{|w| [t(w, scope: :widget), w]}
        g.input :options_as_list, as: :text, input_html: {rows: 5}
        g.input :labels_as_list, as: :text, input_html: {rows: 5}
      end

      g.inputs t('legend.widget'), class: 'inputs inline' do
        g.input :default_value, input_html: {size: 8}
        g.input :minimum_units, input_html: {size: 8}
        g.input :maximum_units, input_html: {size: 8}
        g.input :step, input_html: {size: 8}
      end

      g.inputs t('legend.fiscal'), class: 'inputs inline' do
        g.input :unit_amount, as: :string, input_html: {size: 8}
        g.input :unit_name, input_html: {size: 18}
      end

      g.inputs t('legend.html'), class: 'inputs inline' do
        g.input :required
        g.input :revenue
        g.input :maxlength, as: :string, input_html: {size: 4}
        g.input :size, as: :string, input_html: {size: 4}
        g.input :rows, as: :string, input_html: {size: 4}
        g.input :cols, as: :string, input_html: {size: 4}
        g.input :placeholder, input_html: {size: 18}
      end

      g.input :position, as: :hidden
    end
    f.actions
  end

  show do
    attributes_table do
      row :title
      row :group do |s|
        t(s.group, scope: :group) if s.group?
      end
      row :description do |s|
        RDiscount.new(s.description).to_html.html_safe if s.description?
      end
      row :extra do |s|
        RDiscount.new(s.extra).to_html.html_safe if s.extra?
      end
      row :embed do |s|
        speakerdeck(s.embed) if s.embed?
      end
      row :questions do |s|
        if s.questions.present?
          ul(class: authorized?(:update, s) ? 'sortable' : '') do
            s.questions.each_with_index do |q,index|
              li(id: dom_id(q)) do
                if authorized?(:update, q)
                  i(class: 'icon-move')
                end
                text_node link_to_if authorized?(:update, q), q.name, edit_admin_questionnaire_section_path(s.questionnaire, s, anchor: "section_questions_attributes_#{index}__destroy_input")
              end
            end
          end
        end
      end
    end
  end

  member_action :sort, method: :post do
    resource.questions.each do |q|
      q.set :position, params[:question].index(q.id.to_s)
    end
    render nothing: true, status: 204
  end
end

# coding: utf-8
require 'csv'

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc{ I18n.t('active_admin.dashboard') }

  # Instance variables set here will not be accessible from the template.
  content title: proc{ I18n.t('active_admin.dashboard') } do
    render 'index'
  end

  # @todo Changing language from here will lose the "id" query string parameter,
  #   causing a 404.
  page_action 'summary', title: '@todo' do
    @questionnaire = current_admin_user.questionnaires.find(params[:id])
    authorize! :read, @questionnaire

    # Header
    @starts_on = @questionnaire.starts_on
    @ends_on   = [@questionnaire.today, @questionnaire.ends_on].min

    # Collections
    @responses = @questionnaire.responses
    @questions = @questionnaire.sections.simulator.map(&:questions).flatten
    @fields    = @questionnaire.sections.nonbudgetary
    @number_of_budgetary_questions = @questions.count(&:budgetary?)

    # Timeline and web traffic
    @charts, @statistics = charts @questionnaire

    # Accumulate the totals before calculating the mean.
    @statistics[:mean_number_of_changes] = 0
    @statistics[:mean_magnitude_of_changes] = 0

    @details = {}
    @questions.each do |question|
      details = {}
      if question.budgetary?
        changes = @responses.where(:"answers.#{question.id}".ne => question.default_value)
        number_of_changes = changes.count
        number_of_nonchanges = @statistics[:responses] - number_of_changes

        # How many respondents modified this question?
        details[:percentage_of_population] = number_of_changes / @statistics[:responses].to_f
        @statistics[:mean_number_of_changes] += number_of_changes

        # Start with all the respondents who did not change the value.
        choices = [question.cast_default_value] * number_of_nonchanges
        impacts = []
        magnitude_of_changes = 0

        changes.each do |response|
          impact = response.impact(question)
          choices << response.cast_answer(question)
          impacts << impact
          magnitude_of_changes += impact.abs
        end

        details[:choices] = choices
        details[:minimum_units] = question.minimum_units
        details[:maximum_units] = question.maximum_units
        details[:step] = question.step
        details[:unit_name] = question.unit_name
        details[:default_value] = question.default_value
        details[:widget] = question.widget

        # How large were the modifications?
        details[:mean_choice] = choices.sum / @statistics[:responses].to_f
        details[:mean_impact] = impacts.sum / @statistics[:responses].to_f
        @statistics[:mean_magnitude_of_changes] += magnitude_of_changes

        increases = choices.select{|v| v > question.cast_default_value}
        if increases.empty?
          details[:proportion_who_increase] = 0.0
          details[:mean_increase] = 0.0
        else
          details[:proportion_who_increase] = increases.size / number_of_changes.to_f
          details[:mean_increase] = increases.sum / increases.size.to_f
        end

        decreases = choices.select{|v| v < question.cast_default_value}
        if decreases.empty?
          details[:proportion_who_decrease] = 0.0
          details[:mean_decrease] = 0.0
        else
          details[:proportion_who_decrease] = decreases.size / number_of_changes.to_f
          details[:mean_decrease] = decreases.sum / decreases.size.to_f
        end

        if question.widget == 'option'
          details[:counts] = {}

          question.options.each do |option|
            details[:counts][option] = 0
          end

          changes.each do |response|
            option = response.answer(question)
            details[:counts][option] += 1
          end

          details[:counts].each do |option,count|
            if changes.empty?
              details[:counts][option] = 0
            elsif option == question.default_value
              details[:counts][option] = number_of_nonchanges
            end
          end

          details[:raw_counts] = details[:counts].clone
          details[:n_changes] = changes.size
          details[:options] = question.options
          details[:labels] = question.labels

          details[:counts].each do |option,count|
            details[:counts][option] /= @statistics[:responses].to_f
          end
        end
      # Multiple choice survey questions.
      elsif question.options?
        changes = @responses.where(:"answers.#{question.id}".ne => nil)
        number_of_changes = changes.count
        details[:percentage_of_population] = number_of_changes / @statistics[:responses].to_f

        details[:counts] = {}

        question.options.each do |option|
          details[:counts][option] = 0
        end

        changes.each do |response|
          answer = response.answer(question)
          if question.multiple?
            answer.each do |a|
              details[:counts][a] += 1
            end
          else
            details[:counts][answer] += 1
          end
        end

        details[:counts].each do |answer,count|
          if changes.empty?
            details[:counts][answer] = 0
          end
        end

        details[:raw_counts] = details[:counts].clone
        details[:n_changes] = changes.size

        details[:counts].each do |answer,count|
          details[:counts][answer] /= changes.size.to_f
        end
      end
      @details[question.id.to_s] = details
    end

    if @statistics[:mean_number_of_changes].to_f.nonzero?
      @statistics[:mean_magnitude_of_changes] /= @statistics[:mean_number_of_changes].to_f # perform first
    end
    @statistics[:mean_number_of_changes] /= @statistics[:responses].to_f

    # @see https://github.com/gregbell/active_admin/issues/1362
    render 'summary', layout: 'active_admin'
  end

  # Excel doesn't properly decode UTF-8 CSV and TSV files. A UTF-8 byte order
  # mark (BOM) can be added to fix the problem, but Excel for Mac will still
  # have issues. XLS and XLSX are therefore offered.
  page_action 'raw' do
    @questionnaire = current_admin_user.questionnaires.find(params[:id])
    authorize! :read, @questionnaire

    filename = "data-#{Time.now.strftime('%Y-%m-%d')}.#{params[:format]}"

    # http://www.rfc-editor.org/rfc/rfc4180.txt
    case params[:format]
    when 'csv'
      @col_sep = ','
      headers['Content-Type'] = 'text/csv; charset=utf-8; header=present'
      headers['Content-Disposition'] = %(attachment; filename="#{filename}")
      render layout: false

    when 'tsv'
      @col_sep = "\t"
      headers['Content-Type'] = 'text/tab-delimited-values; charset=utf-8; header=present'
      headers['Content-Disposition'] = %(attachment; filename="#{filename}")
      render layout: false

    when 'xls'
      io = StringIO.new

      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet
      @questionnaire.rows.each_with_index do |row,i|
        sheet.row(i).concat(row)
      end
      book.write(io)

      send_data io.string, filename: filename, type: 'application/vnd.ms-excel'

    when 'xlsx'
      xlsx = Axlsx::Package.new do |package|
        package.workbook.add_worksheet do |sheet|
          @questionnaire.rows.each do |row|
            begin
              sheet.add_row(row)
            rescue ArgumentError => e # non-UTF8 characters from spammers
              logger.error "#{e.inspect}: #{row.inspect}"
            end
          end
        end
      end

      send_data xlsx.to_stream.string, filename: filename, type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    else
      redirect_to admin_root_path, notice: t(:unknown_format)
    end
  end

  controller do
    def index
      @questionnaires = current_admin_user.questionnaires
    end

  protected

    # @param [Questionnaire] q a questionnaire
    # @return [Array] the charts and statistics as a two-value array
    #
    # @see http://analytics-api-samples.googlecode.com/svn/trunk/src/reporting/javascript/ez-ga-dash/docs/user-documentation.html
    # @see http://analytics-api-samples.googlecode.com/svn/trunk/src/reporting/javascript/ez-ga-dash/demos/set-demo.html
    def charts(q)
      charts = {}
      statistics = {}

      # Make all graphs for a consultation have the same x-axis.
      starts_on = q.starts_on - 3.days
      ends_on = [q.today, q.ends_on].min

      begin
        # Responses per day.
        data = []
        hash = q.count_by_date.each_with_object({}) do |row,memo|
          memo[Date.new(row['_id']['year'], row['_id']['month'], row['_id']['day'])] = row['value']
        end
        # Add zeroes so that the chart doesn't interpolate between values.
        starts_on.upto(ends_on).each do |date|
          data << %([#{date_to_js(date)}, #{hash[date] || 0}])
        end

        charts[:responses] = data.join(',')
      rescue Moped::Errors::OperationFailure
        # Do nothing. JS engine is off.
      end

      statistics[:responses] = q.responses.count

      if q.google_analytics_profile? && q.google_api_authorization.authorized?
        begin
          parameters = {
            'ids'        => q.google_analytics_profile,
            'start-date' => starts_on,
            'end-date'   => ends_on,
          }

          # Traffic per day.
          data = q.google_api_authorization.reports(parameters.merge({
            'dimensions' => 'ga:date',
            'metrics'    => 'ga:visitors,ga:visits,ga:pageviews',
            'sort'       => 'ga:date',
          }))
          charts[:visits] = data.rows.map{|row|
            %([#{date_to_js(Date.parse(row[0]))}, #{row[1]}, #{row[2]}, #{row[3]}])
          }.join(',')

          statistics.merge!({
            name:      Questionnaire.sanitize_domain(data.profileInfo['profileName']),
            property:  data.profileInfo['webPropertyId'],
            visitors:  data.totalsForAllResults['ga:visitors'],
            visits:    data.totalsForAllResults['ga:visits'],
            pageviews: data.totalsForAllResults['ga:pageviews'],
          })

          # Traffic sources.
          data = q.google_api_authorization.reports(parameters.merge({
            'dimensions' => 'ga:source',
            'metrics'    => 'ga:visitors',
            'sort'       => '-ga:visitors',
          }))
          charts[:sources] = data.rows.map{|row|
            %(["#{row[0]}", #{row[1]}])
          }.join(',')
        rescue GoogleApiAuthorization::AccessRevokedError, GoogleApiAuthorization::APIError, SocketError
          # Omit the chart if there's an error.
        end
      end

      [charts, statistics]
    end

    # Google Charts needs a Date object, so we can't use #to_json.
    #
    # @param [Date,Time,DateTime] date a date
    def date_to_js(date)
      # JavaScript months start counting from zero.
      "new Date(#{date.year}, #{date.month - 1}, #{date.day})"
    end
  end
end
